/*
 * trace_openat_ftrace.c - Ftrace-based Syscall Tracer
 *
 * Hooks do_sys_openat2 via ftrace and logs file accesses to dmesg.
 * This is the ftrace counterpart to the 'trace_openat' module (which
 * uses kprobes).
 *
 * Key differences from kprobes:
 *   - Ftrace hooks at function entry via NOP->call patching (lower overhead)
 *   - do_sys_openat2 receives args directly in registers (no double pt_regs)
 *   - arm64 uses DYNAMIC_FTRACE_WITH_ARGS: use ftrace_regs_get_argument()
 *   - ftrace_get_regs() returns NULL on arm64 — do NOT use it
 *   - do_sys_openat2 handles both openat and openat2 syscalls
 *
 * Usage:
 *   insmod trace_openat_ftrace.ko
 *   cat /etc/hostname       # triggers log
 *   dmesg | grep trace_openat_ftrace:
 *   echo 1234 > /sys/module/trace_openat_ftrace/parameters/target_pid
 *   rmmod trace_openat_ftrace
 *
 * Requires: CONFIG_FTRACE=y CONFIG_DYNAMIC_FTRACE=y CONFIG_KALLSYMS=y
 */

#include <linux/ftrace.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/version.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("CH0NKY");
MODULE_DESCRIPTION("ftrace-based openat/openat2 logger");
MODULE_VERSION("1.0");

#define MAX_PATH_LEN 256

static unsigned long target_func_addr;

static int target_pid = 0;
module_param(target_pid, int, 0644);
MODULE_PARM_DESC(target_pid, "Only log this PID (0 = log all)");

/*
 * kallsyms_lookup_name is not exported to modules since kernel 5.7.
 * We use the kprobe trick: register a kprobe on the symbol, read
 * back kp.addr, then unregister. This resolves any function symbol.
 * TODO: every time we need a symbol, we create a kprobe.
 * Addresses dont change, and we **could** instead make a lookup table
 * TODO: requires GPL
 * TODO: could somehow use this to find the private kallsym symbols and use them
 * directly **hint hint** **nudge nudge**
 */
static unsigned long kprobe_lookup(const char *name) {
  struct kprobe kp = {.symbol_name = name};
  unsigned long addr;

  // very ugly if you need to find lots of symbols
  if (register_kprobe(&kp) < 0)
    return 0;
  addr = (unsigned long)kp.addr;
  unregister_kprobe(&kp);
  return addr;
}

/*
 * Ftrace callback for do_sys_openat2.
 *
 * On arm64, do_sys_openat2 receives arguments directly:
 *   x0 = dfd (directory file descriptor)
 *   x1 = filename (user pointer)
 *   x2 = how (struct open_how pointer — how->flags is the first member)
 *
 * We use ftrace_regs_get_argument(fregs, N) to read argument N.
 * This is the portable arm64 API
 * ftrace_get_regs() returns NULL on arm64.
 *
 * 'notrace' prevents infinite recursion (tracer tracing itself).
 *  ^Usually not an issue when other drivers are behaving
 */
static void notrace trace_openat_ftrace_callback(unsigned long ip,
                                                 unsigned long parent_ip,
                                                 struct ftrace_ops *op,
                                                 struct ftrace_regs *fregs) {
  // ptr to user data
  const char __user *filename;
  char kbuf[MAX_PATH_LEN];
  int dfd;
  unsigned long how;
  long len;

  /* If target_pid is set, only log that PID */
  if (target_pid > 0 && current->pid != target_pid)
    return;

  // read args
  /* Argument 0 = dfd, Argument 1 = filename, Argument 2 = how */
  dfd = (int)ftrace_regs_get_argument(fregs, 0);
  filename = (const char __user *)ftrace_regs_get_argument(fregs, 1);
  how = ftrace_regs_get_argument(fregs, 2);

  if (!filename)
    return;

  /*
   * strncpy_from_user() with preemption disabled (ftrace context):
   * Safe but not guaranteed. If the user page is resident (the
   * common case for syscall args), the copy succeeds. If the page
   * is swapped out, the fault handler sees pagefault_disabled(),
   * skips the page-in (which would sleep), and returns -EFAULT.
   * We just skip the event in that case — no crash, no deadlock.
   */
  len = strncpy_from_user(kbuf, filename, MAX_PATH_LEN - 1);
  if (len < 0)
    return;

  kbuf[len] = '\0';

  pr_info(
      "trace_openat_ftrace: PID %d (%s) openat(dfd=%d, \"%s\", how=0x%lx)\n",
      current->pid, current->comm, dfd, kbuf, how);
  // now the main function is called
}

static struct ftrace_ops trace_ops = {
    .func = trace_openat_ftrace_callback,
    /*
     * Do NOT set FTRACE_OPS_FL_SAVE_REGS on arm64: it requires
     * HAVE_DYNAMIC_FTRACE_WITH_REGS which arm64 doesn't have (at least i
     * dont think?) arm64 uses DYNAMIC_FTRACE_WITH_ARGS: ftrace_regs always
     * contains argument registers, no flag needed.
     */
    .flags = FTRACE_OPS_FL_RECURSION,
};

// init function installs  ftrace hooks
static int __init trace_openat_ftrace_init(void) {
  int ret;

  /* Step 1: Resolve the target function address via kprobe trick */
  target_func_addr = kprobe_lookup("do_sys_openat2");
  if (!target_func_addr) {
    pr_err("trace_openat_ftrace: failed to find do_sys_openat2\n");
    pr_err("trace_openat_ftrace: ensure CONFIG_KALLSYMS=y\n");
    return -ENOENT;
  }

  pr_info("trace_openat_ftrace: found do_sys_openat2 at %pK\n",
          (void *)target_func_addr);

  /* Step 2: Set ftrace filter to only our target function */
  ret = ftrace_set_filter_ip(&trace_ops, target_func_addr, 0, 0);
  if (ret) {
    pr_err("trace_openat_ftrace: failed to set ftrace filter: %d\n", ret);
    return ret;
  }

  /* Step 3: Register the ftrace function */
  ret = register_ftrace_function(&trace_ops);
  if (ret) {
    pr_err("trace_openat_ftrace: failed to register ftrace: %d\n", ret);
    ftrace_set_filter_ip(&trace_ops, target_func_addr, 1, 0);
    return ret;
  }

  pr_info("trace_openat_ftrace: hook registered on do_sys_openat2\n");
  if (target_pid > 0)
    pr_info("trace_openat_ftrace: filtering to PID %d\n", target_pid);
  else
    pr_info("trace_openat_ftrace: logging all PIDs\n");

  return 0;
}

static void __exit trace_openat_ftrace_cleanup(void) {
  unregister_ftrace_function(&trace_ops);
  ftrace_set_filter_ip(&trace_ops, target_func_addr, 1, 0);
  pr_info("trace_openat_ftrace: hook removed\n");
}

module_init(trace_openat_ftrace_init);
module_exit(trace_openat_ftrace_cleanup);
