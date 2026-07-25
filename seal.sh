#!/usr/bin/env bash
# Seal the built image: de-templatize, compact, lock read-only.
set -euo pipefail

VM="rhel9-golden"
DISK="/var/lib/libvirt/images/${VM}.qcow2"

[[ -f "$DISK" ]] || { echo "Image not found: $DISK" >&2; exit 1; }

# Drop the build domain, keep the disk
sudo virsh destroy  "$VM" 2>/dev/null || true
sudo virsh undefine "$VM" --nvram 2>/dev/null || true

# Regenerate machine-id / SSH host keys on first boot, clear logs & MAC bindings
sudo virt-sysprep -a "$DISK"

# Leftover kickstart check (must print nothing)
sudo virt-ls -a "$DISK" /root | grep -i 'ks.cfg' && echo "WARNING: kickstart left in image" || true

# Compact, then make immutable
sudo qemu-img convert -O qcow2 -c "$DISK" "${DISK}.tmp"
sudo mv -f "${DISK}.tmp" "$DISK"
sudo chmod 0444 "$DISK"
sudo chattr +i "$DISK" 2>/dev/null || true

echo "Sealed. sha256: $(sudo sha256sum "$DISK" | awk '{print $1}')"
echo "Do NOT boot this image - linked clones use it as a backing file."
