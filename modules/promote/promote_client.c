/*
 * promote_client.c - Userland client for the promote kernel module
 *
 * Opens /dev/promote and writes a PID to escalate that process to root.
 * Defaults to promoting itself (getpid()). If self-promotion succeeds,
 * spawns a root shell.
 *
 * Usage:
 *   ./promote_client              # promote self, spawn root shell
 *   ./promote_client 1234         # promote PID 1234 (remote)
 *
 * Build (cross-compile for aarch64):
 *   aarch64-linux-gnu-gcc -Wall -static -o promote_client promote_client.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>

#define DEVICE "/dev/promote"

int main(int argc, char *argv[])
{
	int fd;
	pid_t target;
	char buf[32];
	int len;
	int self;

	if (argc > 1)
		target = atoi(argv[1]);
	else
		target = getpid();

	self = (target == getpid());

	printf("Before: uid=%d euid=%d pid=%d\n", getuid(), geteuid(), getpid());
	printf("Sending PID %d to %s%s\n", target, DEVICE,
	       self ? " (self)" : " (remote)");

	fd = open(DEVICE, O_WRONLY);
	if (fd < 0) {
		perror("open " DEVICE);
		return 1;
	}

	len = snprintf(buf, sizeof(buf), "%d\n", target);
	if (write(fd, buf, len) < 0) {
		perror("write");
		close(fd);
		return 1;
	}

	close(fd);

	printf("After:  uid=%d euid=%d\n", getuid(), geteuid());

	if (self && getuid() == 0) {
		printf("Escalation successful! Spawning root shell...\n");
		execl("/bin/sh", "sh", NULL);
		perror("execl");
	} else if (self) {
		printf("Escalation failed — still uid=%d\n", getuid());
		return 1;
	} else {
		printf("Remote promotion requested for PID %d.\n", target);
		printf("Check: cat /proc/%d/status | grep Uid\n", target);
	}

	return 0;
}
