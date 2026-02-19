# droid — Global CLI Setup Guide

Turn `droid-ctl.sh` into a system-wide `droid` command you can run from anywhere.

---

## Quick Install (one-time setup)

```bash
# 1. Make the script executable
chmod +x droid-ctl.sh

# 2. Copy it to your bin and name it 'droid'
sudo cp droid-ctl.sh /usr/local/bin/droid

# 3. Verify it works
droid help
```

That's it. You can now run `droid <command>` from any directory.

---

## No sudo? Install for your user only

```bash
# Create a local bin if it doesn't exist
mkdir -p "$HOME/.local/bin"

# Copy the script there
cp droid-ctl.sh "$HOME/.local/bin/droid"
chmod +x "$HOME/.local/bin/droid"

# Add to PATH (if not already there)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc    # zsh

# Reload your shell
source ~/.bashrc   # or ~/.zshrc
```

---

## All Commands

```
droid setup              ★ First time? Start here — installs everything
droid doctor             Health check — shows what's missing or broken

droid start              Start emulator
droid stop               Gracefully stop emulator
droid cold               Cold start with full data wipe
droid wipe               Wipe AVD data without starting

droid status             Full status: ADB, device info, memory, apps, network
droid list               List all AVDs on this machine

droid restart-adb        Kill and restart ADB server
droid logs [filter]      Stream logcat  (default: *:W  |  example: *:E)
droid screenshot         Save screenshot as timestamped PNG in current dir
droid install <apk>      Install an APK on the running emulator
droid shell              Open interactive ADB shell on the emulator

droid new                Download system image + create AVD
```

---

## First Time on a New Machine

```bash
droid setup
```

This single command installs and configures everything:

- **Java 17** via your system package manager (`apt` / `dnf` / `pacman` / `brew`)
- **Android Command-Line Tools** downloaded directly from Google
- **SDK licenses** auto-accepted
- **platform-tools** (adb, fastboot), **emulator**, **system image**
- **KVM** hardware acceleration configured (Linux)
- **AVD** created and ready to boot
- **PATH** written to your shell profile (`~/.bashrc` / `~/.zshrc`)

After setup completes, reload your shell and start the emulator:

```bash
source ~/.bashrc      # or ~/.zshrc
droid start
```

---

## Verify Your Environment

```bash
droid doctor
```

Runs a full health check and shows a `✔` or `✘` for every dependency.

---

## Updating droid

When you get a new version of the script, re-run the install:

```bash
sudo cp droid-ctl.sh /usr/local/bin/droid
```

Or for user-only install:

```bash
cp droid-ctl.sh "$HOME/.local/bin/droid"
```

---

## Uninstall

```bash
# System-wide
sudo rm /usr/local/bin/droid

# User-only
rm "$HOME/.local/bin/droid"
```

Remove the PATH block from your `~/.bashrc` or `~/.zshrc` if you also want to clean up the Android SDK entries added by `droid setup`.

---

## Troubleshooting

**`droid: command not found`**
Your PATH doesn't include the install location. Run `source ~/.bashrc` (or `~/.zshrc`) and try again. If that doesn't help, confirm the file exists:
```bash
ls -la /usr/local/bin/droid
# or
ls -la "$HOME/.local/bin/droid"
```

**`Permission denied`**
The script isn't executable. Fix with:
```bash
sudo chmod +x /usr/local/bin/droid
```

**Emulator won't start / is very slow**
Run `droid doctor` — it will tell you if KVM acceleration is missing or if your user isn't in the `kvm` group. After joining the group, log out and back in.

**ADB not finding the emulator**
```bash
droid restart-adb
droid status
```

**Setup failed partway through**
Just run `droid setup` again — it skips steps that already completed successfully.
