# Satty Installer + Capture Script

This project simplifies the installation of [Satty](https://github.com/gabm/Satty), a screenshot editor, along with a helper script called `capture`. It also provides instructions to configure a custom keyboard shortcut in GNOME or KDE.

## 🚀 Installation

### Method 1: Clone the repository

```bash
git clone git@github.com:ajmasia/satty-installer.git
cd satty-installer
./install.sh
```

### Method 2: Install directly without cloning

```bash
curl -fsSL https://raw.githubusercontent.com/ajmasia/satty-installer/main/install.sh | bash
```

### Auto-install dependencies

If you want the installer to automatically install missing dependencies without asking, use the `--yes` flag:

```bash
./install.sh --yes
```

Or remotely:

```bash
curl -fsSL https://raw.githubusercontent.com/ajmasia/satty-installer/main/install.sh | bash -s -- --yes
```

The installer will:

* Download and install the latest version of **Satty** into `/opt/satty`.
* Create a symlink in `/usr/local/bin/satty`.
* Install the `capture` script into `~/.local/bin/capture`.

## 📦 Uninstallation

There are two ways to uninstall Satty and the helper script:

### Method 1: Using the provided script (local)

```bash
./uninstall.sh
```

### Method 2: Run uninstall remotely

```bash
curl -fsSL https://raw.githubusercontent.com/ajmasia/satty-installer/main/uninstall.sh | bash
```

Both methods will remove:

* `/opt/satty`
* `/usr/local/bin/satty`
* `~/.local/bin/capture`

### Method 3: Manual removal

If you prefer, you can manually remove the installed files:

```bash
sudo rm -rf /opt/satty
sudo rm -f /usr/local/bin/satty
rm -f ~/.local/bin/capture
```

## ⌨️ Keyboard Shortcut Setup

The installer **does not automatically create the shortcut**. You must configure it manually:

### GNOME

1. Open **Settings → Keyboard → Custom Shortcuts**.
2. Add a new shortcut with:

   * **Name:** Satty Capture
   * **Command:** `capture`
   * **Shortcut:** `Shift+Super+P` (or your preferred key combo)

### KDE Plasma

1. Open **System Settings → Shortcuts → Custom Shortcuts**.
2. Click **Edit → New → Global Shortcut → Command/URL**.
3. Configure:

   * **Trigger:** `Meta+Shift+P`
   * **Action:** `capture`

## 🖼️ Workflow

1. Press your configured shortcut.
2. Select an area of the screen with `gnome-screenshot` (or `spectacle` in KDE if you adapt the script).
3. Edit in Satty.
4. The file will be saved in `~/Pictures/satty/` and automatically copied to the clipboard.

## ⚠️ Dependencies

The following dependencies are required:

* `curl` or `wget` → to download files.
* `tar` and `install` → to extract and install binaries.
* `jq` (optional) → faster release asset parsing (falls back to grep if missing).
* `gnome-screenshot` (for GNOME users) or `spectacle` (for KDE users, if you adapt the script).
* `wl-copy` → to copy the edited screenshot to the clipboard.
* `notify-send` (from `libnotify-bin`) → to show system notifications.

## 📜 License

This project is licensed under the terms of the [GNU General Public License](./LICENSE).
