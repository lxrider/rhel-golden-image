# rhel-golden-image

Builds a single sealed **RHEL 9 golden image** with Kickstart, used as the
backing file for the linked clones of the lab (RHCSA / EX200 practice).

Scope: this repo builds and seals the image. Cloning, topology and node
roles belong to `linux-lab`.

## Requirements (KVM host, Ubuntu 24.04)

```bash
sudo apt install -y virtinst libvirt-daemon-system ovmf libguestfs-tools qemu-utils
```

## Usage

**1. Check the ISO.** A RHEL 9 **Binary DVD** is expected at
`/var/lib/libvirt/boot/rhel9.iso` (override with `ISO=/path/to.iso`).
It must contain the package trees — a Boot ISO will not do:

```bash
sudo mkdir -p /mnt/iso
sudo mount -o loop,ro /var/lib/libvirt/boot/rhel9.iso /mnt/iso
ls /mnt/iso            # expected: BaseOS/  AppStream/
sudo umount /mnt/iso
```

**2. Build.** Prompts once for a password, then installs unattended
(10-20 min). The VM powers off when done:

```bash
chmod +x scripts/*.sh
./scripts/build.sh
```

Follow it from another shell with `sudo virsh console rhel9-golden`
(exit: `Ctrl+]`).

**3. Seal.** De-templatizes, compacts and locks the image:

```bash
./scripts/seal.sh
```

> Once sealed, the image is **never booted**: linked clones depend on it as
> a read-only backing file.

## What you get

Admin account `labadmin` (group `wheel`), root password set to the same
value, both from the prompt at build time. SSH key of the building user is
installed for `labadmin`.

```text
/boot/efi    600M   vfat
/boot       1024M   xfs
vg_system          lv_root  10G  xfs
                   lv_swap   2G  swap
                   ~8G left unallocated, on purpose
```

## Design notes

- **DVD-only, unregistered** — reproducible, no credentials in the repo.
- **UEFI / GPT** — Red Hat's recommendation for new RHEL 9 deployments;
  boot tasks (`grubby`, `rd.break`) behave identically to BIOS.
- **Stock posture** — SELinux enforcing, firewalld on, no GRUB password
  (required for the RHCSA root-password reset task).
- **Free space left in the VG** — room to practise `lvextend` / `lvcreate`.
- **Nothing pre-configured** that the EX200 expects you to configure.

## Secrets

The repo holds the **template only**. The password hash is generated at build
time into a temp file (mode 0600) that is deleted on exit, and Anaconda's
`/root/anaconda-ks.cfg` is shredded in `%post`. Never commit a rendered `.ks`.
