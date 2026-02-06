#!/bin/bash
# ==============================================================================
# Setup an unprivileged user for the promote module demo
# ==============================================================================
# Run this inside the guest VM before the demo.
# Creates a "student" user so you can demonstrate privilege escalation
# from a non-root account.
# ==============================================================================

set -e

USERNAME="student"
PASSWORD="student"

# Create user if doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/sh "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "Created user '$USERNAME' with password '$PASSWORD'"
else
    echo "User '$USERNAME' already exists"
fi

echo ""
echo "Demo steps:"
echo "  1. insmod /mnt/shared/modules/promote.ko"
echo "  2. su - $USERNAME"
echo "  3. id                                          # uid=1000(student)"
echo "  4. /mnt/shared/modules/promote_client          # promotes self to root"
echo "  5. id                                          # uid=0(root)"
echo ""
echo "Or manually:"
echo "  su - $USERNAME -c 'echo \$\$ > /dev/promote && exec id'"
