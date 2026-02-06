/*
 * procinfo.c - Process Information Module
 *
 * Educational module demonstrating:
 * - The 'current' macro (pointer to current task_struct)
 * - Reading process credentials (UID, GID)
 * - Iterating supplementary groups
 * - Kernel logging with pr_info
 *
 * Usage:
 *   insmod procinfo.ko
 *   dmesg | grep procinfo
 *   rmmod procinfo
 */

#include <linux/cred.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/sched.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Course Instructor");
MODULE_DESCRIPTION("Prints process info on load");
MODULE_VERSION("1.0");

/*
 * module_init — runs when the module is loaded via insmod
 *
 * 'current' points to the task_struct of the process that called insmod.
 * We read its PID, command name, and credentials to demonstrate
 * how kernel code can inspect the calling process.
 */
static int __init procinfo_init(void) {
  const struct cred *cred;
  struct group_info *gi;
  int i;

  /* current_cred() returns a read-only pointer to current->cred */
  cred = current_cred();
  gi = cred->group_info;

  pr_info("procinfo: Loading Process Information Module\n");

  /* Basic task_struct fields */
  pr_info("procinfo: PID  = %d\n", current->pid);
  pr_info("procinfo: TGID = %d\n", current->tgid);
  pr_info("procinfo: COMM = %s\n", current->comm);

  /*
   * Credentials — convert from kernel uid/gid types to plain integers
   * using from_kuid/from_kgid with the initial user namespace.
   */
  pr_info("procinfo: UID  = %d (real)  EUID = %d (effective)\n",
          from_kuid(&init_user_ns, cred->uid),
          from_kuid(&init_user_ns, cred->euid));
  pr_info("procinfo: GID  = %d (real)  EGID = %d (effective)\n",
          from_kgid(&init_user_ns, cred->gid),
          from_kgid(&init_user_ns, cred->egid));

  /*
   * Supplementary groups — stored in cred->group_info as a sorted array.
   * ngroups is the count, gid[] is the array of kgid_t values.
   */
  pr_info("procinfo: Supplementary groups (%d):\n", gi->ngroups);
  for (i = 0; i < gi->ngroups; i++)
    pr_info("procinfo:   group[%d] = %d\n", i,
            from_kgid(&init_user_ns, gi->gid[i]));

  if (gi->ngroups == 0)
    pr_info("procinfo:   (none)\n");

  pr_info("procinfo: ═══════════════════════════════════════\n");

  return 0;
}

/*
 * module_exit — runs when the module is removed via rmmod
 *
 * 'current' now points to the rmmod process, which may be
 * different from the insmod process.
 */
static void __exit procinfo_exit(void) {
  pr_info("procinfo: Goodbye from PID %d (%s)\n", current->pid, current->comm);
}

module_init(procinfo_init);
module_exit(procinfo_exit);
