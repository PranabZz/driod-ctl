#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║           droid-ctl — Android Emulator Control Suite            ║
# ║           Run './droid-ctl.sh setup' to get started             ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── User Config (edit these if needed) ──────────────────────────────
AVD_NAME="Nexus10_Emu"
ANDROID_API="30"
SYSTEM_IMAGE="system-images;android-30;google_apis;x86_64"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
CMDLINE_TOOLS_URL_MAC="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"

# ── Colors & Styles ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────
divider()  { echo -e "${DIM}──────────────────────────────────────────────────${RESET}"; }
label()    { echo -e "${CYAN}${BOLD}▸ $1${RESET}"; }
ok()       { echo -e "  ${GREEN}✔${RESET}  $1"; }
warn()     { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
err()      { echo -e "  ${RED}✘${RESET}  $1"; }
info()     { echo -e "  ${BLUE}•${RESET}  $1"; }
step()     { echo -e "\n  ${MAGENTA}${BOLD}[$1]${RESET}  $2"; }
success()  { echo -e "\n  ${GREEN}${BOLD}$1${RESET}"; }

banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ██████╗ ██████╗  ██████╗ ██╗██████╗      ██████╗████████╗██╗     "
    echo "  ██╔══██╗██╔══██╗██╔═══██╗██║██╔══██╗    ██╔════╝╚══██╔══╝██║     "
    echo "  ██║  ██║██████╔╝██║   ██║██║██║  ██║    ██║        ██║   ██║     "
    echo "  ██║  ██║██╔══██╗██║   ██║██║██║  ██║    ██║        ██║   ██║     "
    echo "  ██████╔╝██║  ██║╚██████╔╝██║██████╔╝    ╚██████╗   ██║   ███████╗"
    echo "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝╚═════╝      ╚═════╝   ╚═╝   ╚══════╝"
    echo -e "${RESET}${DIM}          Android Emulator Management Tool${RESET}"
    echo ""
}

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "mac" ;;
        *)       echo "unknown" ;;
    esac
}

# ── Core Functions ───────────────────────────────────────────────────

is_running() {
    adb devices 2>/dev/null | grep -q "emulator.*device"
}

get_emulator_serial() {
    adb devices 2>/dev/null | grep "emulator.*device" | awk '{print $1}' | head -1
}

wait_for_boot() {
    local serial=$1
    local timeout=${2:-180}
    local elapsed=0
    echo -ne "  ${BLUE}•${RESET}  Waiting for boot"
    while [ $elapsed -lt $timeout ]; do
        local booted
        booted=$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
        if [ "$booted" = "1" ]; then
            echo -e " ${GREEN}✔ Booted!${RESET}"
            return 0
        fi
        echo -ne "."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    echo -e " ${YELLOW}⚠ Timed out${RESET}"
    return 1
}

check_cmd() {
    command -v "$1" &>/dev/null
}

add_to_path_if_missing() {
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$dir:$PATH"
    fi
}

setup_path_for_sdk() {
    add_to_path_if_missing "$ANDROID_HOME/cmdline-tools/latest/bin"
    add_to_path_if_missing "$ANDROID_HOME/platform-tools"
    add_to_path_if_missing "$ANDROID_HOME/emulator"
    add_to_path_if_missing "$ANDROID_HOME/tools/bin"
}

# ════════════════════════════════════════════════════════════════════
# SETUP — Full first-time install wizard
# ════════════════════════════════════════════════════════════════════

cmd_setup() {
    banner
    divider
    label "FIRST-TIME SETUP WIZARD"
    divider
    echo ""
    info "This wizard installs everything needed to run Android emulators."
    info "Each step is skipped if the component is already installed."
    echo ""

    local OS
    OS=$(detect_os)

    if [ "$OS" = "unknown" ]; then
        err "Unsupported OS. This script supports Linux and macOS."
        exit 1
    fi

    info "Detected OS : ${BOLD}$OS${RESET}"
    info "SDK target  : ${BOLD}$ANDROID_HOME${RESET}"
    echo ""

    # ────────────────────────────────────────────────────────────────
    # Step 1: Java
    # ────────────────────────────────────────────────────────────────
    step "1/6" "Java (JDK 17)"
    divider

    if check_cmd java; then
        ok "Java already installed: $(java -version 2>&1 | head -1)"
    else
        warn "Java not found. Installing OpenJDK 17..."
        if [ "$OS" = "linux" ]; then
            if check_cmd apt-get; then
                sudo apt-get update -qq && sudo apt-get install -y openjdk-17-jdk
            elif check_cmd dnf; then
                sudo dnf install -y java-17-openjdk-devel
            elif check_cmd pacman; then
                sudo pacman -S --noconfirm jdk17-openjdk
            elif check_cmd zypper; then
                sudo zypper install -y java-17-openjdk-devel
            else
                err "No supported package manager (apt/dnf/pacman/zypper) found."
                err "Please install JDK 17 manually: https://adoptium.net"
                exit 1
            fi
        elif [ "$OS" = "mac" ]; then
            if check_cmd brew; then
                brew install --cask temurin@17
            else
                err "Homebrew not found. Install it first: https://brew.sh"
                err "Then run: brew install --cask temurin@17"
                exit 1
            fi
        fi

        if check_cmd java; then
            ok "Java installed: $(java -version 2>&1 | head -1)"
        else
            err "Java installation failed. Install JDK 17 manually: https://adoptium.net"
            exit 1
        fi
    fi

    # ────────────────────────────────────────────────────────────────
    # Step 2: System dependencies
    # ────────────────────────────────────────────────────────────────
    step "2/6" "System Dependencies"
    divider

    if [ "$OS" = "linux" ]; then
        if check_cmd apt-get; then
            info "Checking required packages..."
            local missing=()
            for pkg in wget unzip curl libgl1 libpulse0 libnss3 libxtst6 libxrender1; do
                if ! dpkg -s "$pkg" &>/dev/null 2>&1; then
                    missing+=("$pkg")
                fi
            done
            # KVM for hardware acceleration
            if ! ls /dev/kvm &>/dev/null 2>&1; then
                missing+=("qemu-kvm" "cpu-checker")
            fi
            if [ ${#missing[@]} -gt 0 ]; then
                info "Installing: ${missing[*]}"
                sudo apt-get install -y "${missing[@]}"
            else
                ok "All required packages already installed."
            fi
        else
            # Fallback: just check for wget/unzip
            check_cmd wget || warn "wget not found — install it with your package manager"
            check_cmd unzip || warn "unzip not found — install it with your package manager"
        fi

        # KVM group
        if [ -e /dev/kvm ]; then
            if groups | grep -q kvm || [ "$(id -u)" = "0" ]; then
                ok "KVM: accessible."
            else
                info "Adding $USER to kvm group for hardware acceleration..."
                sudo usermod -aG kvm "$USER"
                warn "Log out and back in for KVM group change to take effect."
            fi
        else
            warn "KVM not available — emulator will run without hardware acceleration (slow)."
            warn "On VMs/WSL, this is expected. On bare metal Linux, enable VT-x in BIOS."
        fi

    elif [ "$OS" = "mac" ]; then
        check_cmd wget || { info "Installing wget..."; brew install wget; }
        ok "macOS system dependencies ready."
    fi

    # ────────────────────────────────────────────────────────────────
    # Step 3: Android Command-Line Tools
    # ────────────────────────────────────────────────────────────────
    step "3/6" "Android SDK Command-Line Tools"
    divider

    setup_path_for_sdk

    if check_cmd sdkmanager; then
        ok "sdkmanager already available (v$(sdkmanager --version 2>/dev/null))."
    else
        info "ANDROID_HOME → ${BOLD}$ANDROID_HOME${RESET}"
        mkdir -p "$ANDROID_HOME/cmdline-tools"

        local ZIP_FILE="/tmp/cmdlinetools-$$.zip"
        local DOWNLOAD_URL
        [ "$OS" = "mac" ] && DOWNLOAD_URL="$CMDLINE_TOOLS_URL_MAC" || DOWNLOAD_URL="$CMDLINE_TOOLS_URL"

        info "Downloading Android Command-Line Tools..."
        info "${DIM}$DOWNLOAD_URL${RESET}"

        if check_cmd wget; then
            wget -q --show-progress -O "$ZIP_FILE" "$DOWNLOAD_URL"
        elif check_cmd curl; then
            curl -L --progress-bar -o "$ZIP_FILE" "$DOWNLOAD_URL"
        else
            err "Neither wget nor curl found. Cannot download SDK tools."
            exit 1
        fi

        info "Extracting..."
        unzip -q "$ZIP_FILE" -d "$ANDROID_HOME/cmdline-tools/"
        # Google packages tools inside a 'cmdline-tools' subfolder — rename to 'latest'
        if [ -d "$ANDROID_HOME/cmdline-tools/cmdline-tools" ]; then
            mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
        fi
        rm -f "$ZIP_FILE"
        setup_path_for_sdk

        if check_cmd sdkmanager; then
            ok "sdkmanager installed (v$(sdkmanager --version 2>/dev/null))."
        else
            err "sdkmanager not found after extraction."
            err "Check: $ANDROID_HOME/cmdline-tools/latest/bin/"
            exit 1
        fi
    fi

    # ────────────────────────────────────────────────────────────────
    # Step 4: Accept SDK licenses
    # ────────────────────────────────────────────────────────────────
    step "4/6" "Android SDK Licenses"
    divider

    local lic_file="$ANDROID_HOME/licenses/android-sdk-license"
    if [ -f "$lic_file" ] && [ -s "$lic_file" ]; then
        ok "Licenses already accepted."
    else
        info "Accepting all Android SDK licenses (required)..."
        yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses > /dev/null 2>&1
        ok "Licenses accepted."
    fi

    # ────────────────────────────────────────────────────────────────
    # Step 5: SDK components
    # ────────────────────────────────────────────────────────────────
    step "5/6" "SDK Components"
    divider

    info "Installing platform-tools (adb, fastboot)..."
    sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" > /dev/null 2>&1 && ok "platform-tools ✔"

    info "Installing emulator binary..."
    sdkmanager --sdk_root="$ANDROID_HOME" "emulator" > /dev/null 2>&1 && ok "emulator ✔"

    info "Installing Android platform SDK (API $ANDROID_API)..."
    sdkmanager --sdk_root="$ANDROID_HOME" "platforms;android-$ANDROID_API" > /dev/null 2>&1 && ok "platforms;android-$ANDROID_API ✔"

    info "Installing system image: ${BOLD}$SYSTEM_IMAGE${RESET}"
    warn "(~1–2 GB download — this may take several minutes...)"
    sdkmanager --sdk_root="$ANDROID_HOME" "$SYSTEM_IMAGE" && ok "System image ✔" || {
        err "System image download failed. Check your internet connection and try again."
        exit 1
    }

    # ────────────────────────────────────────────────────────────────
    # Step 6: Create AVD
    # ────────────────────────────────────────────────────────────────
    step "6/6" "Create AVD: $AVD_NAME"
    divider

    setup_path_for_sdk

    if avdmanager list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
        ok "AVD '$AVD_NAME' already exists."
    else
        info "Creating AVD '${BOLD}$AVD_NAME${RESET}' with Nexus 10 device profile..."
        avdmanager create avd \
            -n "$AVD_NAME" \
            -k "$SYSTEM_IMAGE" \
            -d "Nexus 10" \
            --force 2>/dev/null && ok "AVD created." || {
                err "AVD creation failed."
                exit 1
            }
    fi

    # ────────────────────────────────────────────────────────────────
    # PATH persistence
    # ────────────────────────────────────────────────────────────────
    divider
    label "SHELL PATH CONFIGURATION"
    divider

    local shell_rc
    if [ "$SHELL" = "$(command -v zsh 2>/dev/null)" ] || [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ "$SHELL" = "$(command -v fish 2>/dev/null)" ]; then
        shell_rc="$HOME/.config/fish/config.fish"
    else
        shell_rc="$HOME/.bashrc"
    fi

    local marker="Android SDK (added by droid-ctl)"
    local path_block="
# ── $marker ──────────────
export ANDROID_HOME=\"$ANDROID_HOME\"
export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\"
export PATH=\"\$ANDROID_HOME/platform-tools:\$PATH\"
export PATH=\"\$ANDROID_HOME/emulator:\$PATH\"
# ──────────────────────────────────────────────────"

    if grep -q "$marker" "$shell_rc" 2>/dev/null; then
        ok "PATH already configured in $shell_rc"
    else
        echo "$path_block" >> "$shell_rc"
        ok "PATH block written to ${BOLD}$shell_rc${RESET}"
    fi

    # ────────────────────────────────────────────────────────────────
    # Summary
    # ────────────────────────────────────────────────────────────────
    echo ""
    divider
    success "★  SETUP COMPLETE — everything is ready!"
    divider
    echo ""
    ok "Java         : $(java -version 2>&1 | head -1)"
    ok "ADB          : $(adb version 2>/dev/null | head -1)"
    ok "AVD          : $AVD_NAME  (API $ANDROID_API)"
    ok "ANDROID_HOME : $ANDROID_HOME"
    echo ""
    echo -e "  ${YELLOW}${BOLD}Next steps:${RESET}"
    echo ""
    echo -e "  1.  Reload your PATH in this terminal:"
    echo -e "      ${BOLD}source $shell_rc${RESET}"
    echo ""
    echo -e "  2.  Start the emulator:"
    echo -e "      ${BOLD}./droid-ctl.sh start${RESET}"
    echo ""
    echo -e "  3.  Check everything is healthy:"
    echo -e "      ${BOLD}./droid-ctl.sh doctor${RESET}"
    echo ""
}

# ════════════════════════════════════════════════════════════════════
# DOCTOR — Environment health check
# ════════════════════════════════════════════════════════════════════

cmd_doctor() {
    banner
    divider
    label "ENVIRONMENT DOCTOR"
    divider
    echo ""
    setup_path_for_sdk

    local all_ok=true

    _chk() {
        local lbl="$1" val="$2" status="$3"
        printf "  %-24s " "$lbl"
        if [ "$status" = "ok" ]; then
            echo -e "${GREEN}✔${RESET}  $val"
        elif [ "$status" = "warn" ]; then
            echo -e "${YELLOW}⚠${RESET}  $val"; all_ok=false
        else
            echo -e "${RED}✘${RESET}  $val"; all_ok=false
        fi
    }

    check_cmd java      && _chk "Java"        "$(java -version 2>&1 | head -1)" "ok"   \
                        || _chk "Java"        "NOT FOUND — run: ./droid-ctl.sh setup"  "err"

    check_cmd adb       && _chk "ADB"         "$(adb version 2>/dev/null | head -1)"   "ok"  \
                        || _chk "ADB"         "NOT FOUND — run: ./droid-ctl.sh setup"  "err"

    check_cmd sdkmanager && _chk "sdkmanager" "v$(sdkmanager --version 2>/dev/null)" "ok"   \
                         || _chk "sdkmanager" "NOT FOUND — run: ./droid-ctl.sh setup" "err"

    check_cmd avdmanager && _chk "avdmanager" "found" "ok"  \
                         || _chk "avdmanager" "NOT FOUND — run: ./droid-ctl.sh setup" "err"

    check_cmd emulator  && _chk "emulator"    "$(emulator -version 2>/dev/null | head -1 || echo found)" "ok" \
                        || _chk "emulator"    "NOT FOUND — run: ./droid-ctl.sh setup" "err"

    [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ] \
        && _chk "ANDROID_HOME" "$ANDROID_HOME" "ok" \
        || _chk "ANDROID_HOME" "NOT SET or directory missing — run setup" "err"

    if [ "$(detect_os)" = "linux" ]; then
        if [ -e /dev/kvm ]; then
            if groups | grep -q kvm || [ "$(id -u)" = "0" ]; then
                _chk "KVM acceleration" "available + accessible" "ok"
            else
                _chk "KVM acceleration" "device exists but user not in kvm group" "warn"
            fi
        else
            _chk "KVM acceleration" "not available (emulator will be slow)" "warn"
        fi
    fi

    if check_cmd sdkmanager; then
        sdkmanager --list_installed 2>/dev/null | grep -q "system-images;android-$ANDROID_API" \
            && _chk "System image" "API $ANDROID_API installed" "ok" \
            || _chk "System image" "NOT installed — run: ./droid-ctl.sh setup" "err"
    fi

    if check_cmd avdmanager; then
        avdmanager list avd 2>/dev/null | grep -q "Name: $AVD_NAME" \
            && _chk "AVD ($AVD_NAME)" "exists" "ok" \
            || _chk "AVD ($AVD_NAME)" "not found — run: ./droid-ctl.sh new" "warn"
    fi

    is_running \
        && _chk "Emulator running" "YES — $(get_emulator_serial)" "ok" \
        || _chk "Emulator running" "not active" "warn"

    echo ""
    divider
    if $all_ok; then
        success "✔  All checks passed — you're good to go!"
        info "Start your emulator: ${BOLD}./droid-ctl.sh start${RESET}"
    else
        warn "Issues detected. Run ${BOLD}./droid-ctl.sh setup${RESET} to fix them automatically."
    fi
    echo ""
}

# ════════════════════════════════════════════════════════════════════
# STATUS
# ════════════════════════════════════════════════════════════════════

cmd_status() {
    banner
    setup_path_for_sdk
    divider; label "EMULATOR STATUS"; divider

    local emulator_lines
    emulator_lines=$(adb devices 2>/dev/null | grep "emulator")

    if [ -z "$emulator_lines" ]; then
        warn "No emulators detected."
    else
        echo "$emulator_lines" | while read -r line; do
            local serial state
            serial=$(echo "$line" | awk '{print $1}')
            state=$(echo  "$line" | awk '{print $2}')
            [ "$state" = "device"  ] && ok   "Online:  ${BOLD}$serial${RESET}"
            [ "$state" = "offline" ] && warn "Offline: ${BOLD}$serial${RESET}"
        done
    fi

    echo ""; divider; label "ADB SERVER"; divider
    local av
    av=$(adb version 2>/dev/null | head -1)
    [ -n "$av" ] && ok "$av" || err "ADB not found — run: ${BOLD}./droid-ctl.sh setup${RESET}"

    if is_running; then
        local s; s=$(get_emulator_serial)

        echo ""; divider; label "DEVICE INFO  [$s]"; divider
        info "Android : ${BOLD}$(adb -s "$s" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')${RESET}  (SDK $(adb -s "$s" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r'))"
        info "Device  : ${BOLD}$(adb -s "$s" shell getprop ro.product.brand 2>/dev/null | tr -d '\r') $(adb -s "$s" shell getprop ro.product.model 2>/dev/null | tr -d '\r')${RESET}"
        info "Build   : $(adb -s "$s" shell getprop ro.build.id 2>/dev/null | tr -d '\r')"
        info "Screen  : $(adb -s "$s" shell wm size 2>/dev/null | tr -d '\r')   $(adb -s "$s" shell wm density 2>/dev/null | tr -d '\r')"

        echo ""; divider; label "SYSTEM RESOURCES  [$s]"; divider
        local cpu
        cpu=$(adb -s "$s" shell cat /proc/cpuinfo 2>/dev/null | grep "model name" | head -1 | cut -d: -f2 | xargs)
        [ -z "$cpu" ] && cpu=$(adb -s "$s" shell cat /proc/cpuinfo 2>/dev/null | grep "Hardware" | head -1 | cut -d: -f2 | xargs)
        info "CPU     : ${cpu:-unknown}"
        local mt ma
        mt=$(adb -s "$s" shell cat /proc/meminfo 2>/dev/null | grep MemTotal     | awk '{print $2}')
        ma=$(adb -s "$s" shell cat /proc/meminfo 2>/dev/null | grep MemAvailable | awk '{print $2}')
        if [ -n "$mt" ] && [ -n "$ma" ]; then
            info "Memory  : $(( (mt-ma)/1024 ))MB used / $(( mt/1024 ))MB total  ($(( (mt-ma)*100/mt ))%)"
        fi
        local df
        df=$(adb -s "$s" shell df /data 2>/dev/null | tail -1 | awk '{print $2, $3, $4}')
        [ -n "$df" ] && info "Storage : $df (total / used / free)"

        echo ""; divider; label "RUNNING APPS  [$s]"; divider
        adb -s "$s" shell ps 2>/dev/null \
            | grep -v "^USER\|kworker\|ksoftirq\|migration\|^root\|^system" \
            | awk '{print $9}' | grep "\." | head -8 \
            | while read -r app; do info "$app"; done

        echo ""; divider; label "NETWORK  [$s]"; divider
        local ip
        ip=$(adb -s "$s" shell ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}')
        [ -z "$ip" ] && ip=$(adb -s "$s" shell ifconfig eth0 2>/dev/null | grep "inet addr" | awk '{print $2}' | cut -d: -f2)
        info "IP Address : ${ip:-unavailable}"
    fi
    echo ""
}

# ════════════════════════════════════════════════════════════════════
# OTHER COMMANDS
# ════════════════════════════════════════════════════════════════════

cmd_restart_adb() {
    banner; divider; label "RESTARTING ADB SERVER"; divider
    setup_path_for_sdk
    info "Killing server..."; adb kill-server; sleep 1
    info "Starting server..."; adb start-server; sleep 1
    ok "Done."
    echo -e "\n${DIM}$(adb devices 2>/dev/null)${RESET}\n"
}

cmd_start() {
    banner; divider; label "START EMULATOR"; divider
    setup_path_for_sdk
    if is_running; then
        ok "Emulator already running: $(get_emulator_serial)"
    else
        info "Launching: ${BOLD}$AVD_NAME${RESET}  [gpu:host | accel:on | no-snapshot]"
        nohup emulator -avd "$AVD_NAME" -gpu host -accel on -no-snapshot > /tmp/droid-ctl-emu.log 2>&1 &
        ok "Process started (PID: $!)"
        echo ""; info "Polling for emulator on ADB..."; sleep 5
        local i=0
        while ! is_running && [ $i -lt 15 ]; do echo -ne "."; sleep 2; i=$((i+1)); done
        echo ""
        if is_running; then
            local s; s=$(get_emulator_serial); ok "Online: $s"
            wait_for_boot "$s" 180
        else
            warn "Emulator not yet visible. Check /tmp/droid-ctl-emu.log"
        fi
    fi
    echo ""
}

cmd_stop() {
    banner; divider; label "STOP EMULATOR"; divider
    setup_path_for_sdk
    if is_running; then
        local s; s=$(get_emulator_serial)
        info "Shutting down $s..."
        adb -s "$s" emu kill 2>/dev/null; sleep 2
        if is_running; then
            warn "Graceful shutdown failed. Force-killing..."
            pkill -f "emulator.*$AVD_NAME" 2>/dev/null || pkill -f emulator 2>/dev/null
            ok "Force killed."
        else
            ok "Stopped cleanly."
        fi
    else
        warn "No emulator running."
    fi
    echo ""
}

cmd_cold() {
    banner; divider; label "COLD START (WIPE DATA)"; divider
    setup_path_for_sdk
    warn "This will WIPE all emulator data!"
    echo -ne "  ${YELLOW}?${RESET}  Confirm? [y/N] "; read -r c
    [[ ! "$c" =~ ^[Yy]$ ]] && { info "Aborted."; echo ""; return; }
    info "Stopping running emulator..."; pkill -f emulator 2>/dev/null; sleep 2
    info "Cold starting ${BOLD}$AVD_NAME${RESET}..."
    nohup emulator -avd "$AVD_NAME" -wipe-data -no-snapshot -gpu host -accel on > /tmp/droid-ctl-emu.log 2>&1 &
    ok "Cold start initiated (PID: $!)"; sleep 6
    if is_running; then
        local s; s=$(get_emulator_serial); ok "Online: $s"; wait_for_boot "$s" 180
    else
        info "Starting in background. Use ${BOLD}status${RESET} to monitor."
    fi
    echo ""
}

cmd_new() {
    banner; divider; label "CREATE NEW AVD: $AVD_NAME"; divider
    setup_path_for_sdk
    info "Image : $SYSTEM_IMAGE"; info "API   : $ANDROID_API"; echo ""
    info "Installing system image (may take a few minutes)..."
    sdkmanager --sdk_root="$ANDROID_HOME" "$SYSTEM_IMAGE" "platforms;android-$ANDROID_API" || {
        err "sdkmanager failed. Run ${BOLD}./droid-ctl.sh setup${RESET} first."
        return 1
    }
    echo ""; info "Creating AVD..."
    avdmanager create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" -d "Nexus 10" --force \
        && ok "AVD '$AVD_NAME' created." \
        || err "AVD creation failed."
    echo ""
}

cmd_logs() {
    setup_path_for_sdk
    ! is_running && { err "No emulator running."; echo ""; return 1; }
    local s; s=$(get_emulator_serial); local f="${1:-*:W}"
    banner; divider; label "LOGCAT  [$s]  filter: $f  |  Ctrl+C to stop"; divider
    adb -s "$s" logcat "$f"
}

cmd_screenshot() {
    setup_path_for_sdk
    banner; divider; label "SCREENSHOT"; divider
    ! is_running && { err "No emulator running."; echo ""; return 1; }
    local s; s=$(get_emulator_serial)
    local out="screenshot_$(date +%Y%m%d_%H%M%S).png"
    info "Capturing from $s..."
    adb -s "$s" exec-out screencap -p > "$out"
    [ -s "$out" ] && ok "Saved: ${BOLD}$(pwd)/$out${RESET}" || { err "Screenshot failed."; rm -f "$out"; }
    echo ""
}

cmd_install() {
    setup_path_for_sdk
    banner; divider; label "INSTALL APK"; divider
    local apk="$1"
    [ -z "$apk" ]   && { err "Usage: droid-ctl install <path.apk>"; echo ""; return 1; }
    [ ! -f "$apk" ] && { err "File not found: $apk"; echo ""; return 1; }
    ! is_running    && { err "No emulator running."; echo ""; return 1; }
    local s; s=$(get_emulator_serial)
    info "Installing ${BOLD}$apk${RESET} → $s"
    adb -s "$s" install -r "$apk" && ok "Installed." || err "Installation failed."
    echo ""
}

cmd_shell() {
    setup_path_for_sdk
    ! is_running && { err "No emulator running."; return 1; }
    local s; s=$(get_emulator_serial)
    info "Shell on $s  (type 'exit' to quit)"; divider
    adb -s "$s" shell
}

cmd_list_avds() {
    setup_path_for_sdk
    banner; divider; label "AVAILABLE AVDs"; divider
    local list; list=$(avdmanager list avd 2>/dev/null)
    [ -z "$list" ] && { warn "No AVDs found. Run: ${BOLD}./droid-ctl.sh new${RESET}"; echo ""; return; }
    echo "$list" | while IFS= read -r line; do
        echo "$line" | grep -q "Name:"  && echo -e "  ${GREEN}${BOLD}$line${RESET}" && continue
        echo "$line" | grep -q "Error:" && echo -e "  ${RED}$line${RESET}"          && continue
        echo -e "  ${DIM}$line${RESET}"
    done
    echo ""
}

cmd_wipe() {
    banner; divider; label "WIPE AVD DATA"; divider
    is_running && { warn "Stop emulator first: ${BOLD}./droid-ctl.sh stop${RESET}"; echo ""; return 1; }
    warn "This deletes all user data for ${BOLD}$AVD_NAME${RESET}."
    echo -ne "  ${YELLOW}?${RESET}  Confirm? [y/N] "; read -r c
    [[ ! "$c" =~ ^[Yy]$ ]] && { info "Aborted."; echo ""; return; }
    local p="$HOME/.android/avd/${AVD_NAME}.avd"
    [ -d "$p" ] && {
        rm -f "$p/userdata-qemu.img" "$p/userdata.img" "$p/cache.img"
        rm -rf "$p/snapshots"
        ok "Wiped: $p"
    } || warn "AVD path not found: $p"
    echo ""
}

cmd_help() {
    banner
    divider
    echo -e "  ${BOLD}USAGE${RESET}  ./droid-ctl.sh <command> [args]"
    divider
    echo ""
    echo -e "  ${MAGENTA}${BOLD}★ NEW USER? START HERE${RESET}"
    echo -e "  ${BOLD}setup${RESET}              Auto-installs Java, SDK, emulator & creates AVD"
    echo -e "  ${BOLD}doctor${RESET}             Health check — shows what's missing or broken"
    echo ""
    echo -e "  ${CYAN}${BOLD}EMULATOR CONTROL${RESET}"
    echo -e "  ${BOLD}start${RESET}              Start emulator (skips if already running)"
    echo -e "  ${BOLD}stop${RESET}               Gracefully stop the running emulator"
    echo -e "  ${BOLD}cold${RESET}               Cold start with full data wipe"
    echo -e "  ${BOLD}wipe${RESET}               Wipe AVD data without starting"
    echo ""
    echo -e "  ${CYAN}${BOLD}INFORMATION${RESET}"
    echo -e "  ${BOLD}status${RESET}             Full status: ADB, device info, memory, apps, network"
    echo -e "  ${BOLD}list${RESET}               List all AVDs on this machine"
    echo ""
    echo -e "  ${CYAN}${BOLD}ADB & TOOLING${RESET}"
    echo -e "  ${BOLD}restart-adb${RESET}        Kill and restart the ADB server"
    echo -e "  ${BOLD}logs [filter]${RESET}      Stream logcat  (default: *:W)"
    echo -e "  ${BOLD}screenshot${RESET}         Save screenshot as timestamped PNG"
    echo -e "  ${BOLD}install <apk>${RESET}      Install APK on running emulator"
    echo -e "  ${BOLD}shell${RESET}              Open ADB shell on running emulator"
    echo ""
    echo -e "  ${CYAN}${BOLD}SETUP${RESET}"
    echo -e "  ${BOLD}new${RESET}                Download system image + create AVD '$AVD_NAME'"
    echo ""
    echo -e "  ${DIM}Config: AVD=$AVD_NAME  |  API=$ANDROID_API  |  SDK=$ANDROID_HOME${RESET}"
    echo ""
}

# ── Router ───────────────────────────────────────────────────────────
case "$1" in
    setup)           cmd_setup ;;
    doctor)          cmd_doctor ;;
    status)          cmd_status ;;
    start)           cmd_start ;;
    stop)            cmd_stop ;;
    cold)            cmd_cold ;;
    wipe)            cmd_wipe ;;
    restart-adb)     cmd_restart_adb ;;
    logs)            cmd_logs "$2" ;;
    screenshot)      cmd_screenshot ;;
    install)         cmd_install "$2" ;;
    shell)           cmd_shell ;;
    list)            cmd_list_avds ;;
    new)             cmd_new ;;
    help|--help|-h)  cmd_help ;;
    *)               cmd_help ;;
esac
