// SPDX-License-Identifier: GPL-2.0
/*
 * template.c - Kernel Module Template
 *
 * Rename this file to match your module directory name.
 * For example: modules/mymod/mymod.c
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A simple kernel module template");
MODULE_VERSION("1.0");

/* Module parameters (optional) */
static int param_value = 42;
module_param(param_value, int, 0644);
MODULE_PARM_DESC(param_value, "An example parameter");

/* Called when module is loaded */
static int __init template_init(void)
{
    pr_info("Module loaded! param_value = %d\n", param_value);
    return 0;  /* 0 = success, negative = error */
}

/* Called when module is unloaded */
static void __exit template_exit(void)
{
    pr_info("Module unloaded!\n");
}

module_init(template_init);
module_exit(template_exit);
