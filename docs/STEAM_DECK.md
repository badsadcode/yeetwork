# Playing Yeetwork on Steam Deck (and Windows / Linux PCs)

Yeetwork has native **Linux** and **Windows** builds. The Steam Deck runs the Linux build
natively (no Proton needed), with full controller support and a graphics preset tuned
for the Deck.

## 1. Getting the game

Builds are produced automatically by GitHub Actions on every push
(`.github/workflows/build.yml`):

- **Latest build:** open the repository's **Actions** tab, then the latest green
  *Test & Export* run. Download **Yeetwork-Linux** (Steam Deck / Linux) or
  **Yeetwork-Windows** from *Artifacts*. Downloading artifacts requires being signed in
  to GitHub with access to the repo, so it may be easiest for the repo owner to download
  and send the file.
- **Releases:** pushing a tag like `v0.2.0` publishes a GitHub Release with both files
  attached:
  ```bash
  git tag v0.2.0
  ```
  ```bash
  git push origin v0.2.0
  ```

You can also export locally from the Godot editor: *Project → Export → Linux / Windows →
Export Project*. You need the 4.7.2 export templates (*Editor → Manage Export
Templates*).

## 2. Installing on the Steam Deck

1. Hold the power button and choose **Switch to Desktop**.
2. Download `Yeetwork-Linux-x86_64.tar.gz` (Firefox/Chrome, or copy it over USB).
3. Right-click it, choose **Extract archive here**, and move the folder somewhere like
   `~/Games/Yeetwork`.
4. Make sure `Yeetwork.x86_64` is executable: right-click it, then *Properties →
   Permissions → Is executable*.
5. Open **Steam** (desktop), then **Games → Add a Non-Steam Game to My Library…**.
   Click **Browse…**, select `Yeetwork.x86_64` (set the file type filter to *All Files*),
   and click **Add Selected Programs**.
6. Go back to **Gaming Mode** (desktop shortcut *Return to Gaming Mode*). Yeetwork is in
   your Library under *Non-Steam*.

### Controller setup
In Gaming Mode open Yeetwork's **Controller Settings** and pick the **Gamepad with
Gyro** or **Gamepad with Mouse Trackpad** template. Gyro or trackpad aiming makes
gravity-gun shots and catches much easier.

| Action | Deck |
|---|---|
| Move / look | Left stick / right stick (or gyro / right trackpad) |
| Jump (hold = bunny hop) | A |
| Crouch / slide | B or L3 |
| Gravity gun: grab, pull, catch | L2 (left trigger) |
| Throw (hold to charge) / punt | R2 (right trigger) |
| Freeze held prop | R1 / X |
| Spawn prop (sandbox) / pick prop | Y / D-pad left & right |
| Third-person camera | D-pad up |
| Respawn | D-pad down |
| Scoreboard / menu | View (☰ left) / Menu (≡ right) |

Typing a name or an IP address: press **STEAM + X** for the on-screen keyboard. The menus
work with the D-pad, A to select, and B to close the pause menu.

### Performance
On the Deck the game automatically uses **Graphics: Low**. That's 75% resolution with
FSR upscaling, no SDFGI or SSIL, and simplified fog. **Medium** is available in the
settings if you want prettier lighting. In the Deck's quick menu (**…** button) a
**60 FPS / 60 Hz** limit gives smooth play. Use 40-45 FPS for longer battery life.

## 3. Playing together

One player **hosts** (menu → *HOST / PLAY*) and everyone else **joins** with the host's
address (menu → *Join a friend*).

- **Same Wi-Fi / home network:** the host opens the pause menu (Esc / Menu button) to see
  "friends join: 192.168.x.x". Type that address on the Deck and press *JOIN*.
- **Over the internet:** the host either forwards **UDP port 24642** on their router to
  their PC, or (easier) everyone installs a free virtual LAN like **Tailscale** or
  **ZeroTier** and uses the host's Tailscale/ZeroTier address. Tailscale works on the
  Steam Deck in desktop mode.
- Everyone needs the **same game version**, and the same map files for custom maps.
- Windows asks to allow Yeetwork through the firewall the first time you host. Allow it
  on *private* networks.

## 4. Windows notes

Unzip `Yeetwork-Windows-x86_64.zip` and run `Yeetwork.exe`. The build is not code-signed,
so SmartScreen may say "Windows protected your PC". Click **More info → Run anyway**.
