set -euo pipefail

INTEL_ZIP_URL="https://github.com/raandomdev/Noteab-Macro/releases/tag/hotfix3/MacteabMacro.zip"
ARM_DMG_URL="https://github.com/raandomdev/Noteab-Macro/releases/download/v2.1.7-hotfix2/MacteabMacro.dmg"
DOWNLOAD_DIR="$HOME/Downloads"
PYTHON_PKG_URL="https://www.python.org/ftp/python/3.12.13/python-3.12.13-macos11.pkg"
VENV_DIR="$HOME/.macteab-macro/venv"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This script is intended for macOS only." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required but was not found." >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "Homebrew is installed but the brew binary could not be found." >&2
    exit 1
fi

brew update
brew install --formula tesseract

PROFILE_FILE="$HOME/.zprofile"
if [[ ! -f "$PROFILE_FILE" ]]; then
    touch "$PROFILE_FILE"
fi

BREW_PREFIX="$(brew --prefix)"
PATH_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
EXPORT_LINE="export PATH=\"$BREW_PREFIX/bin:$BREW_PREFIX/sbin:\$PATH\""

if ! grep -Fq "$PATH_LINE" "$PROFILE_FILE" 2>/dev/null; then
    {
        echo
        echo "# Added by setup_macos_ocr.sh"
        echo "$PATH_LINE"
        echo "$EXPORT_LINE"
    } >> "$PROFILE_FILE"
fi

export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
export TESSERACT_PATH="$BREW_PREFIX/bin/tesseract"

if command -v tesseract >/dev/null 2>&1; then
    tesseract --version | head -n 1
else
    echo "Tesseract was installed, but the binary is still not on PATH." >&2
    echo "Open a new terminal or run: source ~/.zprofile" >&2
    exit 1
fi

echo "Tesseract setup complete."

install_python_if_missing() {
    if command -v python3 >/dev/null 2>&1; then
        echo "Python already installed ($(python3 --version)), skipping Python download."
        return
    fi

    echo "No Python installation found. Downloading Python 3.12..."
    PKG_DEST="$DOWNLOAD_DIR/python-3.12.13-macos11.pkg"
    curl -fL --progress-bar -o "$PKG_DEST" "$PYTHON_PKG_URL"
    echo "Downloaded installer to: $PKG_DEST"

    echo "Opening the Python installer. Please complete the install wizard (you'll be asked for your admin password)."
    open "$PKG_DEST"

    PYTHON_BIN_DIR="/Library/Frameworks/Python.framework/Versions/3.12/bin"

    while true; do
        read -r -p "Press Enter once the Python installer has finished (or type 'skip' to abort): " REPLY_INPUT
        if [[ "$REPLY_INPUT" == "skip" ]]; then
            echo "Aborting: Python is required for the rest of this script." >&2
            exit 1
        fi

        export PATH="$PYTHON_BIN_DIR:$PATH"
        if command -v python3 >/dev/null 2>&1; then
            break
        fi

        echo "python3 still isn't on PATH — if the installer is still open, finish it and press Enter again."
    done

    PYTHON_PATH_LINE="export PATH=\"$PYTHON_BIN_DIR:\$PATH\""
    if ! grep -Fq "$PYTHON_PATH_LINE" "$PROFILE_FILE" 2>/dev/null; then
        {
            echo
            echo "# Added by setup_macos_ocr.sh (Python 3.12)"
            echo "$PYTHON_PATH_LINE"
        } >> "$PROFILE_FILE"
    fi

    echo "Python 3.12 installed and confirmed on PATH: $(python3 --version)"
}

create_venv() {
    echo "Creating an isolated virtual environment at: $VENV_DIR"
    mkdir -p "$(dirname "$VENV_DIR")"
    python3 -m venv "$VENV_DIR"

    VENV_PIP="$VENV_DIR/bin/pip"
    VENV_PYTHON="$VENV_DIR/bin/python3"

    "$VENV_PIP" install --upgrade pip setuptools wheel
    "$VENV_PIP" install --upgrade pytesseract

    VENV_ACTIVATE_LINE="# Run: source \"$VENV_DIR/bin/activate\"  (to use MacteabMacro's Python env)"
    if ! grep -Fq "$VENV_DIR/bin/activate" "$PROFILE_FILE" 2>/dev/null; then
        {
            echo
            echo "# Added by setup_macos_ocr.sh (MacteabMacro venv)"
            echo "$VENV_ACTIVATE_LINE"
        } >> "$PROFILE_FILE"
    fi

    echo "Virtual environment ready. Python packages will install here instead of the system/Homebrew Python."
}

warn_if_placeholder_url() {
    local url="$1"
    local marker="$2"
    if [[ "$url" == *"$marker"* ]]; then
        echo "NOTE: this URL may be a placeholder guess — verify it points at the real asset" >&2
        echo "      on the GitHub release page before relying on this download." >&2
    fi
}

ARCH="$(uname -m)"
mkdir -p "$DOWNLOAD_DIR"

install_python_if_missing
create_venv

case "$ARCH" in
    arm64)
        echo "Detected Apple Silicon (arm64)."

        echo "Downloading MacteabMacro.zip..."
        warn_if_placeholder_url "$INTEL_ZIP_URL" "PLACEHOLDER"
        DEST="$DOWNLOAD_DIR/MacteabMacro.zip"
        curl -fL --progress-bar -o "$DEST" "$INTEL_ZIP_URL"
        echo "Downloaded to: $DEST"
        ;;
    x86_64)
        echo "Detected Intel (x86_64)."

        echo "Downloading MacteabMacro.zip..."
        warn_if_placeholder_url "$INTEL_ZIP_URL" "MacteabMacro.zip"
        DEST="$DOWNLOAD_DIR/MacteabMacro.zip"
        curl -fL --progress-bar -o "$DEST" "$INTEL_ZIP_URL"
        echo "Downloaded to: $DEST"
        ;;
    *)
        echo "Unrecognized architecture: $ARCH" >&2
        exit 1
        ;;
esac

echo "Installing required Python packages into the venv..."
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install --upgrade \
    numpy \
    opencv-python-headless \
    Pillow \
    pyautogui \
    pytesseract \
    requests \
    psutil \
    pyobjc \
    pyperclip \
    ttkbootstrap \
    pywebview \
    discord.py \
    pynput \
    pyinstaller

echo "Python packages installed into: $VENV_DIR"
echo "Setup complete. Restart your terminal, or run:"
echo "  source ~/.zprofile"
echo "  source \"$VENV_DIR/bin/activate\"    # to use this project's Python env"
