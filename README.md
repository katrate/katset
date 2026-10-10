# KATSET OS

A personal Linux distribution built from **Linux From Scratch 13.1 (systemd)** —
from raw source tarballs all the way to a bootable ISO, with a fully custom
desktop: the **KATSET shell** (design: `docs/katset-design.md`).

> **Name:** KATSET OS v1.0.0 — *"Better days ahead."*
> **Target machine:** HP Pavilion 14-ec0xxx (Ryzen 5 5500U, Radeon Vega 7)

## Key decisions

| Area          | Choice                                        | Why |
|---------------|-----------------------------------------------|-----|
| Base system   | LFS **13.1 systemd** (current stable)         | Total control; systemd book is the only maintained line now |
| Build env     | **VirtualBox** VM: Debian 13.7 build host + separate blank target disk | Snapshots = free rollbacks; host/target separation mirrors real distro builds. *Debian is only the workshop — zero Debian code ships in KATSET* |
| Init          | systemd (baked into LFS 13.1)                 | What desktop stacks expect |
| Packages      | **pacman (ALPM)** + self-hosted binary repo   | Real dependency resolution; proven at scale |
| Desktop       | **KATSET shell** — custom QML shell on Quickshell + wlroots compositor (Hyprland/sway) | Original experience built from the provided design, not a reskin of stock |
| Shell design  | User-provided mock → [`docs/katset-design.md`](docs/katset-design.md) | Full component inventory + architecture |
| Bootloader    | GRUB (UEFI)                                  | Universal |
| ISO           | squashfs + GRUB eltorito/hybrid                | Standard live/install media |

## Roadmap

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 0 | Build environment: VirtualBox, Debian build host VM, target disk, repo scaffold | ✅ done |
| 1 | LFS 13.1 built end-to-end → first login on the target disk | ⬜ *waiting on Debian install* |
| 2 | Base system: systemd, NetworkManager, users, sudo, ssh | ⬜ |
| 3 | BLFS: kernel firmware, Mesa/AMDGPU, PipeWire, Wayland + **KATSET shell** | ⬜ |
| 4 | pacman + package recipes + local binary repo | ⬜ |
| 5 | Live ISO: initramfs pivot, squashfs, GRUB, branding | ⬜ |
| 6 | Install to real hardware, daily-driver hardening (power, Wi-Fi, BT) | ⬜ |
| ∥ | **Shell track:** KATSET shell developed in the VM in parallel (starts after Debian is up) | ⬜ |

## Repository layout

```
distro/
├── README.md            ← you are here
├── scripts/             Windows-side automation (VM creation, tooling installs)
├── build/               Scripts that run INSIDE the build host VM (phases 1-3)
├── shell/               KATSET shell source — QML/Quickshell (parallel track)
├── repo/                pacman package recipes + binary repo output (phase 4)
├── iso/                 ISO assembly tooling (phase 5)
├── branding/            Logos, plymouth, wallpapers, greeter/GRUB themes
├── docs/                Hardware notes, design analysis, phase guides, LFS book
└── .cache/              Downloads & logs (gitignored)
```

## Quick start (phase 0)

1. `scripts/install-virtualbox.ps1` — self-elevating, silent VirtualBox install
2. `scripts/create-vm.ps1` — creates the build-host VM (Debian 13.7, 6 CPU / 8 GB,
   NAT + SSH forward on `127.0.0.1:2222`) with a second blank target disk
3. Install Debian into the VM from `.cache/debian-13.7.0-amd64-netinst.iso`
4. Follow `docs/01-phase1-lfs.md` for the LFS build

## Conventions

- Windows scripts: PowerShell, work from repo root, log to `.cache/`
- VM-side scripts: bash, run as `lfs` user or root as documented
- Everything reproducible: if a step isn't scripted, it's documented in `docs/`
