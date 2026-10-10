# Target hardware: HP Pavilion 14-ec0xxx

Inventory taken from Windows (Phase 0). Items marked ⚠ need verification once
Linux is running on real hardware (Phase 6) or from a live session.

| Component | Device | Linux support plan |
|-----------|--------|--------------------|
| CPU | AMD Ryzen 5 5500U (6C/12T, Zen 2, "Lucienne") | `amd_pstate` cpufreq, `amd-ucode` microcode |
| iGPU | AMD Radeon Graphics (Vega 7) | `amdgpu` + Mesa + LLVM, VAAPI (`radeonsi`), OpenCL optional |
| Wi-Fi | **Realtek RTL8852AE** (Wi-Fi 6, PCIe) | in-kernel `rtw89` (≥5.16) + `linux-firmware` (rtw89/rtl8852ae fw) ⚠ |
| Bluetooth | Realtek Wireless BT (pairs with RTL8852AE) | `linux-firmware` (rtl_bt/) + bluez ⚠ |
| Audio | Realtek High Definition Audio + AMD HDMI | `snd-hda-intel`; possible SOF path → `linux-firmware` (sof/), then PipeWire |
| Touchpad | ELAN PrecisionTouchpad over I2C | `i2c-hid-acpi` + `hid-multitouch` (precision touchpad = standard protocol) |
| Fingerprint | ELAN WBF sensor | libfprint — ⚠ often unsupported for ELAN WBF; treat as bonus |
| Display | 14" eDP panel (assume 1080p+) | eDP + `amdgpu` DSI/eDP, backlights via `amdgpu_bl*` ⚠ |
| Storage | ⚠ unverified (likely NVMe) | `nvme` driver; verify model in Phase 6 |
| Power | HP ACPI | `hp-wmi`, ACPI quirks, TLP for battery life |
| Webcam / SD reader | ⚠ not inventoried yet | check with `lsusb`/`lspci` on first boot |

## Known risk areas

1. **RTL8852AE** — Realtek firmware is the usual weak point of custom distros.
   Mitigation: ship full `linux-firmware`, keep kernel ≥ 6.x (we're on 7.1.8).
2. **HP ACPI quirks** — hotkey/brightness keys may need `acpi_osi` or hp-wmi quirks.
3. **Suspend/resume on AMD** — test s2idle early; `amdgpu` runtime PM matters.

## Build VM hardware (VirtualBox)

- Build host VM: Debian 13.7, 6 CPUs / 8 GB RAM / 40 GB dynamic disk
- LFS target disk: 80 GB dynamic (separate vdi, blank at creation)
- NAT + port forward `127.0.0.1:2222 → guest:22`
