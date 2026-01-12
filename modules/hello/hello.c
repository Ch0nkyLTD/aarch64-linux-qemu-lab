#include <linux/module.h>  // Needed by all modules
#include <linux/kernel.h>  // Needed for KERN_INFO
#include <linux/init.h>    // Needed for the macros

// Metadata about the module
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Course Instructor");
MODULE_DESCRIPTION("A simple Hello World AArch64 Driver");
MODULE_VERSION("1.0");

// This function runs when the module is loaded (insmod)
static int __init hello_start(void)
{
    // pr_info is the modern replacement for printk(KERN_INFO ...)
    pr_info("Hello, AArch64! The kernel is alive.\n");
    return 0;
}

// This function runs when the module is removed (rmmod)
static void __exit hello_end(void)
{
    pr_info("Goodbye, AArch64! Unloading module.\n");
}

// macros to register the entry and exit points
module_init(hello_start);
module_exit(hello_end);
