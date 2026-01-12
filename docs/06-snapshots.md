# Snapshots and Reset

This guide covers managing VM state with snapshots and reset functionality.

## Overview

The lab uses QCOW2 images which support:
- **Snapshots**: Save/restore points within the runtime image
- **Reset**: Return to clean golden image state

## Image Layers

```
Layer 1: debian-rootfs-base.img (raw)
    └── Never modified after creation

Layer 2: debian-rootfs.qcow2 (backed by Layer 1)
    └── Golden image - your configured baseline

Layer 3: debian-runtime.qcow2 (backed by Layer 2)
    └── Your experiments and snapshots
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `make snapshot NAME=foo` | Create snapshot |
| `make restore NAME=foo` | Restore to snapshot |
| `make snapshots` | List all snapshots |
| `make reset` | Full reset to golden image |

## Creating Snapshots

Before making changes you might want to undo:

```bash
make snapshot NAME=before-experiment
```

Or with the script directly:

```bash
./scripts/snapshot.sh create before-experiment
```

### Naming Conventions

Good snapshot names:
- `clean` - Just after boot
- `before-kprobe-test` - Before risky experiment
- `working-driver` - After successful implementation
- `day1` - End of session

## Listing Snapshots

```bash
make snapshots
```

Output:
```
>>> Snapshots in debian-runtime.qcow2:

Snapshot list:
ID        TAG                 VM SIZE                DATE       VM CLOCK
1         before-experiment   0 B      2024-01-15 10:30:00   00:00:00.000
2         working-driver      0 B      2024-01-15 11:45:00   00:00:00.000
```

## Restoring Snapshots

```bash
make restore NAME=before-experiment
```

This restores the runtime image to the snapshot state.

**Note**: VM must be stopped before restoring.

## Deleting Snapshots

```bash
./scripts/snapshot.sh delete old-snapshot
```

## Full Reset

Discard ALL changes and return to golden image:

```bash
make reset
```

This:
1. Deletes `debian-runtime.qcow2`
2. Creates fresh runtime backed by golden image

### When to Reset

- Corrupted filesystem
- Unbootable system
- Start fresh for new exercise
- Clean up after experiments

## Image Information

View image details:

```bash
make info
```

Or:
```bash
./scripts/snapshot.sh info
```

Shows:
- Image format and size
- Backing file chain
- Snapshot list

## Workflow Examples

### Experiment Safely

```bash
# Save state before risky work
make snapshot NAME=before-risky

# Do experiment
make shared
# ... break something ...

# Oops! Restore
make restore NAME=before-risky
```

### Daily Work

```bash
# Start of session
make reset              # Fresh start
make snapshot NAME=clean

# Work...
make snapshot NAME=checkpoint1

# More work...
make snapshot NAME=checkpoint2

# End of session - optionally reset for tomorrow
make reset
```

### Module Development

```bash
# After successful module test
make snapshot NAME=hello-works

# Try modifications
# ...

# Didn't work, go back
make restore NAME=hello-works
```

## Advanced: Manual QCOW2 Operations

### Create Snapshot with qemu-img

```bash
qemu-img snapshot -c mysnapshot debian-runtime.qcow2
```

### Apply Snapshot

```bash
qemu-img snapshot -a mysnapshot debian-runtime.qcow2
```

### Delete Snapshot

```bash
qemu-img snapshot -d mysnapshot debian-runtime.qcow2
```

### View Image Info

```bash
qemu-img info debian-runtime.qcow2
```

### Check Image Integrity

```bash
qemu-img check debian-runtime.qcow2
```

## Live Snapshots (VM Running)

QEMU also supports live snapshots via the monitor.

While VM is running, press `Ctrl-a c` for monitor:

```
(qemu) savevm mysnapshot
(qemu) loadvm mysnapshot
(qemu) delvm mysnapshot
(qemu) info snapshots
```

Press `Ctrl-a c` again to return to guest.

**Note**: Live snapshots include VM memory state, so they're larger but preserve exact execution state.

## Backing File Chain

View the backing file relationship:

```bash
qemu-img info --backing-chain debian-runtime.qcow2
```

Output:
```
image: debian-runtime.qcow2
file format: qcow2
backing file: debian-rootfs.qcow2
backing file format: qcow2

image: debian-rootfs.qcow2
file format: qcow2
backing file: debian-rootfs-base.img
backing file format: raw

image: debian-rootfs-base.img
file format: raw
```

## Rebasing Images

To flatten layers (make standalone image):

```bash
# Create standalone copy
qemu-img convert -O qcow2 debian-runtime.qcow2 standalone.qcow2

# Or rebase to different backing file
qemu-img rebase -b new-base.qcow2 debian-runtime.qcow2
```

## Troubleshooting

### "Image is in use"

VM is still running. Stop it first:
- In guest: `poweroff`
- Or: `Ctrl-a x` to kill QEMU

### Snapshot Not Found

```bash
make snapshots  # Check exact name
```

### Corrupted Image

```bash
# Check for errors
qemu-img check debian-runtime.qcow2

# If corrupted, reset
make reset
```

### Out of Disk Space

Snapshots consume space. Delete old ones:

```bash
./scripts/snapshot.sh delete old-snapshot
```

Or reset to reclaim all space:

```bash
make reset
```

## Best Practices

1. **Snapshot before experiments**: Always save state before risky changes
2. **Use descriptive names**: `before-kprobe` not `snap1`
3. **Clean up old snapshots**: They consume disk space
4. **Reset regularly**: Start fresh for new exercises
5. **Don't snapshot golden image**: Keep Layer 2 clean

## Next Steps

- [04-debugging.md](04-debugging.md) - Debugging with GDB
- [07-troubleshooting.md](07-troubleshooting.md) - Common issues
