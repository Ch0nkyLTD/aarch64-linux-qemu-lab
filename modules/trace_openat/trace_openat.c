/*
 * trace_openat.c - Syscall Tracer Module
 *
 * Registers kprobes on __arm64_sys_openat and __arm64_sys_openat2.
 * The pre-handler extracts dfd, filename, and flags from registers
 * and logs them to dmesg with a "trace_openat:" prefix.
 *
 * Optional: set target_pid to only log a specific process.
 *
 * Usage:
 *   insmod trace_openat.ko
 *   cat /etc/hostname       # triggers log
 *   dmesg | grep trace_openat:
 *   echo 1234 > /sys/module/trace_openat/parameters/target_pid
 *   rmmod trace_openat
 */

#include <asm/ptrace.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/sched.h>
#include <linux/uaccess.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("CH0nky dev");
MODULE_DESCRIPTION("Syscall tracer - kprobe-based openat/openat2 logger");
MODULE_VERSION("1.0");

#define MAX_PATH_LEN 256

static int target_pid = 0;
module_param(target_pid, int, 0644);
MODULE_PARM_DESC(target_pid, "Only log this PID (0 = log all)");

// hook handler!
static int trace_openat_handler(struct kprobe *p, struct pt_regs *regs) {
  struct pt_regs *user_regs;
  char __user *filename_ptr;
  char kbuf[MAX_PATH_LEN];
  int dfd;
  unsigned long flags;
  long len;

  /* If target_pid is set, only log that PID */
  if (target_pid > 0 && current->pid != target_pid)
    return 0;

  /*
   * man openat
   * AArch64 syscall double-indirection:
   * regs->regs[0] points to the actual user pt_regs,
   * user_regs->regs[0] = dfd
   * user_regs->regs[1] = filename
   * user_regs->regs[2] = flags (openat) or struct open_how* (openat2)
   */
  user_regs = (struct pt_regs *)regs->regs[0];
  dfd = (int)user_regs->regs[0];
  filename_ptr = (char __user *)user_regs->regs[1];
  flags = user_regs->regs[2];

  /*
   * strncpy_from_user() in kprobe context (preemption disabled):
   * Safe but not guaranteed. If the user page is resident (the
   * common case for syscall args), the copy succeeds. If the page
   * is swapped out, the fault handler sees pagefault_disabled(),
   * skips the page-in (which would sleep), and returns -EFAULT.
   * We just skip the event in that case because it probably means
   * something went wrong someewhere else, or is supe rare
   */
  len = strncpy_from_user(kbuf, filename_ptr, MAX_PATH_LEN - 1);
  if (len < 0)
    return 0;

  kbuf[len] = '\0';

  pr_info("trace_openat: PID %d (%s) openat(dfd=%d, \"%s\", flags=0x%lx)\n",
          current->pid, current->comm, dfd, kbuf, flags);

  return 0;
}

static struct kprobe kp_openat = {
    .symbol_name = "__arm64_sys_openat",
    .pre_handler = trace_openat_handler,
};

static struct kprobe kp_openat2 = {
    .symbol_name = "__arm64_sys_openat2",
    .pre_handler = trace_openat_handler,
};

// setup kprobes
static int __init trace_openat_init(void) {
  int ret;

  ret = register_kprobe(&kp_openat);
  if (ret < 0) {
    pr_err("trace_openat: fatal: failed to register kprobe on %s: %d\n",
           kp_openat.symbol_name, ret);
    return ret;
  }

  ret = register_kprobe(&kp_openat2);
  if (ret < 0) {
    pr_warn("trace_openat: openat2 kprobe failed (%d) \n", ret);
  }

  pr_info("trace_openat: kprobes registered (openat%s)\n",
          kp_openat2.addr ? "+openat2" : " only");
  if (target_pid > 0)
    pr_info("trace_openat: filtering to PID %d\n", target_pid);
  else
    pr_info("trace_openat: logging all PIDs\n");

  return 0;
}

static void __exit trace_openat_exit(void) {
  if (kp_openat2.addr)
    unregister_kprobe(&kp_openat2);
  if (kp_openat.addr)
    unregister_kprobe(&kp_openat);
  pr_info("trace_openat: kprobes unregistered\n");
}

module_init(trace_openat_init);
module_exit(trace_openat_exit);
