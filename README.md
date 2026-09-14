# Chaotic Fingers

**Chaotic Fingers** is a professional macOS utility designed to safeguard your workstation from accidental inputs—perfect for when your little ones are around, or when you simply need to clean your hardware. It provides a sleek, modern interface to selectively disable your keyboard and trackpad.

## 🌟 Features

- **Selective Input Blocking**:
  - **Keyboard**: Disables all physical key presses.
  - **Trackpad**: Disables cursor movement and clicks.
  - **Both**: Complete lockdown of all primary inputs.
- **Modern Adaptive UI**:
  - **Premium Design**: Built with semantic system colors for a native "Glassmorphism" look.
  - **Themes**: Full support for **Light**, **Dark**, and **System Default** modes.
- **Smart Recovery Gestures**: Hardware-level escape combinations to re-enable your inputs instantly.
- **Flexible Visibility**:
  - Toggle visibility in the **Dock**, **Menu Bar**, and **Finder**.
  - Optional **Launch at Login** support.

## 🛠 Smart Recovery Gestures

If the app window is hidden and inputs are blocked, use these physical gestures (hold for 3 seconds):

- **Keyboard Mode**: Hold **Left Shift + Right Shift**
- **Trackpad Mode**: Hold **Left Option + Right Option**
- **Both Mode**: Hold **Left Command + Right Command**

## 📦 Installation & Setup

### 1. Simple Installation (DMG)
1. Navigate to the `dist/` folder and open `ChaoticFingers-Installer.dmg`.
2. Drag **Chaotic Fingers** into your **Applications** folder.

### 2. Permissions (CRITICAL)
Because Chaotic Fingers manages hardware inputs, it requires **Accessibility Permissions**:
1. Open the app.
2. If prompted, click **"Open System Settings"**.
3. Toggle the switch for **Chaotic Fingers** under *Privacy & Security > Accessibility*.

### 3. First Launch on other Macs
If you share the app with others, macOS Gatekeeper may block it. To open it:
1. Go to **System Settings > Privacy & Security**.
2. Scroll down and click **"Open Anyway"** for Chaotic Fingers.

## 🚀 Development & Packaging

### Build from Source
```bash
swift build -c release
```

### Create a DMG Installer
Use the provided packaging script to generate a distributable DMG:
```bash
bash package.sh
```
The resulting installer will be saved in `dist/ChaoticFingers-Installer.dmg`.

### Code signing and the Accessibility grant

`package.sh` signs with the first `Developer ID Application` or `Apple Development`
identity it finds in your keychain. Override it explicitly if you have several:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" bash package.sh
```

**This matters more than it looks.** An ad-hoc signature (`--sign -`) makes the
app's designated requirement a bare `cdhash`, which changes on every build, so
macOS treats each rebuild as a different app and the Accessibility permission
has to be granted again every single time. A real identity produces a
requirement based on the bundle id plus the certificate, which is identical
across rebuilds — grant it once and it sticks.

If no identity is found the script still works, but falls back to ad-hoc and
warns you that the permission will keep resetting.

To clear stale Accessibility entries left behind by earlier ad-hoc builds:

```bash
tccutil reset Accessibility com.rajeev.ChaoticFingers
```

Note: an `Apple Development` certificate is fine on your own Mac. Distributing
to *other* Macs without warnings additionally requires a `Developer ID
Application` certificate and notarization.

---
Designed with ❤️ for parents and hardware enthusiasts.
