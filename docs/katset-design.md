# KATSET OS — Desktop Design Analysis & DE Architecture

**Design:** provided 2025-10-13 mock ("KATSET_OS v1.0.0", tagline *"BETTER DAYS AHEAD."*)
**Status:** analysis complete — implementation is Phase 3 (runs in parallel with LFS Phases 1–2)

---

## 1. Design inventory

### Chrome (always-on surfaces)

| Element | Notes |
|---|---|
| **Top bar** | `KATSET` wordmark left · tagline + progress underline · right cluster: toggle icons (capture/DND), volume, Wi-Fi, Bluetooth, date, clock · accent gradient hairline (magenta→cyan) below |
| **Left dock** | Vertical glass strip: launcher, file manager, browser, Discord, Spotify, VS Code, terminal, Steam, settings, alerts, trash |
| **Bottom bar** | Center: `SYSTEM ONLINE` launcher with app tiles + storage sizes (Valorant 27 GB, Chrome 1.2 GB, …) · Left: now-playing mini (title/artist + EQ bars) · Right: `KATSET_OS v1.0.0` badge |
| **Window style** | Floating, rounded, thin glowing border, custom titlebar (file manager shows back/fwd nav + breadcrumb + search) |

### Widget system (the signature of this design)

| Widget | Data sources |
|---|---|
| Hero clock + date + rotating quote | local time, `quotes.json` |
| Media player (art, progress, controls, **queue**) | **MPRIS** D-Bus (Spotify/any player) |
| Quick links (This PC, Downloads, Documents…) | XDG user dirs |
| System monitor: CPU% / GPU% / RAM% **ring gauges** + freq graphs | `/proc/stat`, amdgpu `hwmon` (Radeon), `/proc/meminfo` |
| SSD gauge + graph (180/475 GB) | `df` / `statvfs` |
| Network down/up sparklines | `/proc/net/dev` deltas, NM D-Bus |
| Temp panel: CPU / GPU / Battery % | `k10temp`/`amdgpu` hwmon (lm_sensors), **UPower** |
| Calendar (today highlighted) | local |
| Quick Notes (checkbox list) | local JSON → sync later |
| File manager (sidebar, capacity bars) | XDG dirs, `statvfs` |
| Current Vibes widget (art + EQ bars) | MPRIS + audio visualizer |
| Terminal snippet (aesthetic) | decorative — feeds real TTY log |

### Look & feel

- **Palette:** near-black navy base `#0a0e17`, panel `#111827`/`#16213e` @ ~80% opacity + **blur**, accent blue `#3b82f6`→`#5b9dff`, cyan glow `#22d3ee`, magenta accent `#d946ef`, text `#e6edf7`
- **Shape language:** 12–16 px radii, 1px luminous borders, glow on focus, sparkline/graph mini-visuals everywhere
- **Type:** display face ≈ *Chakra Petch / Rajdhani* (techy, squared) + UI face ≈ *Inter* (to confirm)
- **Imagery:** cyberpunk cityscape wallpaper (need the source file, not the mock — ask user)

---

## 2. Architecture (how a custom DE actually gets built)

```
┌─ KATSET Shell (our code — QML) ──────────────────────────┐
│  top bar · left dock · widget stack · launcher · mini players │
│  (layer-shell surfaces: panels float above/beside windows)    │
├─ Shell runtime: Quickshell (QtQuick/QML) ───────────────┤
│  QML = the design's blur/gradients/animations are native here │
├─ Compositor: wlroots-based (Hyprland primary / sway fallback) │
│  window mgmt, XWayland, blur&animation, keybinds, screenshare │
├─ Session: greetd (greeter) + hyprlock-style lock + systemd     │
├─ Data: D-Bus → NetworkManager, UPower, MPRIS, lm_sensors,     │
│        PipeWire (EQ/visualizer), PipeWire/Wayland portals      │
├─ Theme layer: Qt theme (custom QML) + GTK4 theme for apps      │
│  + icon set + font set + sound theme                            │
└─ Apps: themed GTK file manager first → custom QML apps later   │
```

### Why this stack (researched 2026-10)

| Choice | Alternatives | Rationale |
|---|---|---|
| **Quickshell** for the shell | AGS v3/Astal (GTK4), eww, SDF (new Rust) | QML/QtQuick does shaders, blur, springs, path animations *natively* — this design is glossy/animated; hardware-accelerated; made exactly for bars/lockers/widgets. AGS is the close runner-up if we prefer GTK/Lua |
| **Hyprland** as compositor engine | sway (no animations), niri (scroll-tiling), river, Wayfire, **own compositor on Smithay** | Design needs blur + animations + floating windows → Hyprland fits. ⚠ verify its 2026 licensing/subscription situation before shipping; sway = conservative fallback (plain but unbreakable) |
| **Not a from-scratch compositor (yet)** | Smithay (Rust), wlroots C | Own compositor = months before first pixel. Start on an engine; the shell is where *our* identity lives. Revisit "KATSET compositor" as a v2 project |
| **greetd** greeter | SDDM, GDM | Light, themeable with our own greeter UI later |

**Key insight:** panels, docks, widgets = `wlr-layer-shell` surfaces — they don't care
which wlroots compositor runs underneath. Our shell is portable across
Hyprland/sway/river, so compositor choice is reversible.

---

## 3. Build strategy (parallel track)

The shell doesn't need LFS to exist — **develop it inside the Debian build-host VM**
(Hyprland + Quickshell + a dev session), then package the result into KATSET OS
during Phase 3:

| Track | When | Deliverable |
|---|---|---|
| **A — LFS build** (phases 1–2) | now | bootable text-mode KATSET base |
| **B — Shell dev** (new `shell/` dir, in VM) | starts after Debian is up, parallel to A | top bar + left dock + clock + system widgets running in the VM |
| **C — Integration** (phase 3) | after A | shell + Wayland + theme + greeter + apps inside KATSET OS |
| **D — Custom apps** (FM, launcher polish) | phase 3+ | the file manager, `SYSTEM ONLINE` launcher, notes sync |

### Widget build order (v1 = most visible wins first)

1. Top bar (wordmark, clock, volume/Wi-Fi/BT status) + left dock — *defines the silhouette*
2. Hero clock, system-monitor rings, network/temp panels — *the right-side stack*
3. Media player + Current Vibes (MPRIS) + now-playing mini
4. Calendar, quick notes, quick links
5. `SYSTEM ONLINE` launcher (app tiles + sizes)
6. Custom file manager window (start: themed existing FM → replace)
7. Greeter, lock screen, splash, GRUB theme, TTY splash

---

## 4. Open questions (need from user)

- [ ] **Wallpaper source file** (the mock embeds it; want full-res PNG/JPG)
- [ ] Fonts: approve *Chakra Petch* (display) + *Inter* (UI)? Or the mock's exact faces
- [ ] Notes: local-only or sync (Notion API was hinted in the mock)?
- [ ] Is the design 1440p@100% scale (mock resolution) — target DPI/scaling for the laptop's panel?
- [ ] Window layout preference: the mock shows floating windows — default float or smart-tiling?
