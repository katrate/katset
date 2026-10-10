# Phase 1 — Building LFS 13.1 on the target disk

**Book (authoritative):** <https://www.linuxfromscratch.org/lfs/view/13.1-systemd/>
**Offline copy:** `docs/book/LFS-BOOK-13.1-NOCHUNKS.html` (open in a browser)
**Machine:** VM `lfs-buildhost` — Debian 13.7 host, 6 CPU / 8 GB, UEFI (OVMF)

This doc only records **our environment-specific deltas**. Everything not mentioned
here: follow the book literally.

## Verified deltas (book → our setup)

| Topic | Book assumption | Our setup | Why |
|---|---|---|---|
| Target disk | `/dev/sda` | **`/dev/sdb`** (80 GB blank 2nd disk) | sda = Debian build host |
| Partition table | BIOS/MBR examples | **GPT**: `sdb1` 512 MB ESP (vfat) + `sdb2` root (ext4) | real laptop boots UEFI |
| Firmware | BIOS default | **UEFI** — GRUB built as §8.65.2 (`--target=x86_64 --with-platform=efi`) | matches hardware; VBox OVMF |
| GRUB install | `grub-install` (BIOS) | **`grub-install --target=x86_64-efi --removable`** → writes `EFI/BOOT/BOOTX64.EFI` | book: LFS has no efibootmgr, `--removable` is the supported path; also what VBox firmware auto-boots |
| Network iface name | `<network-device-name>` | **`enp0s3`** (VBox NIC) → use `Name=en*` in .network file | NAT DHCP works out of the box |
| `$LFS` | `/mnt/lfs` | `/mnt/lfs` (no change) | — |

## Step 0 — Debian install (interactive)

```
VBoxManage startvm lfs-buildhost
```

Boot menu → *Debian installer* (UEFI). Partitioning:

- **"Guided — use entire disk"** → select the **40 GB** disk (VBOX HARDDISK #1).
  ⚠ There are two disks — the 80 GB one must stay **untouched and unformatted**.
- Mirror/country: whatever's fastest. Software selection: **standard system
  utilities + OpenSSH server** (no desktop environment — build host stays lean).
- Create user `distro` (sudoer) — password remembered in `.cache/credentials.txt`.*

After reboot + login:

```
# eject installer media, boot from disk only
VBoxManage storageattach lfs-buildhost --storagectl SATA --port 2 --device 0 --medium emptydrive
VBoxManage modifyvm lfs-buildhost --boot1 disk --boot2 dvd
VBoxManage snapshot lfs-buildhost take debian-pristine
```

\* I'll generate this file when we set up the credentials.

## Step 1 — Host prerequisites (as `distro`, sudo)

```bash
sudo apt update
sudo apt install -y build-essential bison gawk gettext m4 texinfo python3 \
    wget curl rsync xz-utils zip unzip file patch psmisc util-linux
```

These cover LFS ch.2 *Host System Requirements* (Debian versions exceed every
minimum). Sanity check: `gcc --version && make --version && bison --version`.

## Step 2 — Partition & mount the target (book §2.4–2.7, our commands)

```bash
lsblk                    # confirm: sda = Debian, sdb = 80G empty
sudo parted --script /dev/sdb \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart root ext4 513MiB 100%
sudo mkfs.vfat -F32 -n EFISYS /dev/sdb1
sudo mkfs.ext4 -L lfsroot /dev/sdb2
sudo mkdir -p /mnt/lfs
sudo mount /dev/sdb2 /mnt/lfs
sudo mkdir -p /mnt/lfs/boot/efi
sudo mount /dev/sdb1 /mnt/lfs/boot/efi
```

Book §2.5: `export LFS=/mnt/lfs`, `umask 022`. From here on, follow the book
**chapters 3 → 8** as written (as `lfs` user for ch4-6, chroot for ch7-8).

## Step 3 — Book chapters 3-8 (the long compile)

- **Ch 3:** download sources into `$LFS/sources` (sticky dir per book). Our copy
  of the URL list: `docs/book/wget-list-13.1.txt` — but use the book's own
  wget-list script; verify with the book's md5sums step.
- **Ch 5–6:** cross toolchain + temp tools. Expect ~1–1.5 h total.
- **Ch 7:** chroot + temp tools (~40 min).
- **Ch 8:** final system (~1.5–3 h sequential). Test suites: run every suite the
  book marks; save logs (`make check 2>&1 | tee logs/pkg.log`). If a suite
  fails, screenshot/note it — many are known-flaky, but decide with me before
  moving on (a broken glibc/gcc test = stop).
- **No `make -j` unless the book says so** for that package (some builds race).

Set `export LFS=/mnt/lfs` again in every new shell — losing it is the #1
beginner failure (book §4.2 explains why).

## Step 4 — Ch 9 (systemd config): our values

- `/etc/hostname`: `lfs-dev` (rename to the real distro name later)
- DHCP networking (VBox NAT):

  ```bash
  cat > /etc/systemd/network/10-ether.network << "EOF"
  [Match]
  Name=en*

  [Network]
  DHCP=yes
  EOF
  ```

- Follow the book for systemd-resolved symlink, `/etc/hosts`, locale, inputrc,
  shells, machine-id.
- Set root password (use a strong one; credentials go in `.cache/credentials.txt`,
  gitignored):

  ```bash
  passwd root
  ```

  A dev user + `sudo` arrive in Phase 2 with the `sudo` package — for now,
  root on the console/SSH is fine.

## Step 5 — Ch 10 (bootable): our sequence

1. **fstab** (book §10.1) — adapt to our layout:

   ```
   UUID=<esp-uuid>   /boot/efi  vfat  umask=0077          0  2
   UUID=<root-uuid>  /          ext4  defaults            0  1
   ```
   Get UUIDs: `blkid /dev/sdb1 /dev/sdb2`. ⚠ Do **not** copy the book's
   example verbatim — it assumes sda2.

2. **Kernel** (book §10.2): `make defconfig` then apply **all** of the book's
   UEFI-related config additions listed in §10.3 (the book walks through the
   EFI options — follow them exactly). ext4 is built-in via defconfig; no
   initramfs is used, so root fs must stay built-in.

3. **GRUB** (book §10.4): skip §8.65.1 (BIOS) — configure per §8.65.2 instead:

   ```bash
   sed 's/--image-base/--nonexist-linker-option/' -i configure   # book's grub bugfix
   ./configure --prefix=/usr --sysconfdir=/etc \
       --target=x86_64 --with-platform=efi --disable-efiemu --disable-werror
   make && make install
   ```

   Then in chroot with ESP mounted (per book §10.4 UEFI section):

   ```bash
   grub-install --target=x86_64-efi --removable
   grub-mkconfig -o /boot/grub/grub.cfg
   ```

   `--removable` = `EFI/BOOT/BOOTX64.EFI` fallback path → zero NVRAM/efibootmgr
   dependency, and VBox's OVMF boots it automatically.

## Step 6 — First boot

```
VBoxManage startvm lfs-buildhost
```

Expect: OVMF → GRUB → systemd → login prompt. Checklist:

- [ ] `login as root` works
- [ ] `ip a` → `enp0s3` has a 10.0.2.x address (networkd + DHCP file from ch9)
- [ ] `ping -c3 10.0.2.2` (host) and `ping -c3 1.1.1.1`
- [ ] `resolvectl status` shows upstream DNS (VBox NAT provides 10.0.2.3)
- [ ] `systemctl --failed` is empty

Then snapshot:

```
VBoxManage snapshot lfs-buildhost take phase1-lfs-bootable
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| OVMF drops to EFI shell / no GRUB | ESP missing `EFI/BOOT/BOOTX64.EFI` | re-run `grub-install --target=x86_64-efi --removable` in chroot with ESP mounted |
| `grub>` prompt / `error: no such partition` | grub.cfg has wrong `root=` | check `search --set=root` line vs `blkid`; `grub-mkconfig` again |
| Kernel panic: "VFS: unable to mount root fs" | ext4 not built-in, or wrong `root=` UUID | `grep EXT4 .config` → `=y`; verify `root=` in grub.cfg |
| Boots but no network | .network file match wrong | `Name=en*`; `systemctl restart systemd-networkd systemd-resolved` |
| Stuck in chroot: "no such file or directory" on binaries | lost `$LFS` or skipped book's chroot env command | re-run book §7.2 `chroot "$LFS" … env -i … bash` exactly |
| Build died mid-chapter | out of memory/typo/partial build | check `dmesg \| grep -i oom` (8 GB is enough); fix, re-run that package only — don't restart the book |
