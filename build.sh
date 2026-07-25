#!/usr/bin/env bash
# Build the RHEL 9 golden image from kickstart (UEFI, DVD-only).
# Run as a normal user from the repo root: ./scripts/build.sh
set -euo pipefail

ISO="${ISO:-/var/lib/libvirt/boot/rhel9.iso}"
KEY="${KEY:-$HOME/.ssh/id_ed25519.pub}"
VM="rhel9-golden"
DISK="/var/lib/libvirt/images/${VM}.qcow2"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ISO" ]] || { echo "ISO not found: $ISO" >&2; exit 1; }
[[ -f "$KEY" ]] || { echo "Public key not found: $KEY" >&2; exit 1; }

# Password is hashed here and never written to the repo
read -rsp "Password for root and labadmin: " PW; echo
HASH="$(openssl passwd -6 "$PW")"; unset PW

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed -e "s|@PW_HASH@|${HASH}|g" \
    -e "s|@SSH_KEY@|$(cat "$KEY")|g" \
    "${REPO}/kickstart/rhel9-golden.ks.tmpl" > "${TMP}/ks.cfg"
chmod 600 "${TMP}/ks.cfg"

sudo virt-install \
  --name "$VM" \
  --memory 2048 --vcpus 2 \
  --osinfo detect=on,require=off \
  --disk "path=${DISK},size=20,format=qcow2,bus=virtio" \
  --network network=default,model=virtio \
  --location "$ISO" \
  --initrd-inject "${TMP}/ks.cfg" \
  --extra-args "inst.ks=file:/ks.cfg inst.text console=ttyS0,115200n8" \
  --boot uefi --graphics none --noautoconsole --wait -1 --noreboot

echo "Build done. Next: ./scripts/seal.sh"
