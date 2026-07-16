set -euo pipefail

INTEL_ZIP_URL="https://github.com/raandomdev/Noteab-Macro/releases/download/v2.1.7-hotfix2/MacteabMacro.zip"
ARM_DMG_URL="https://github.com/raandomdev/Noteab-Macro/releases/download/v2.1.7-hotfix2/MacteabMacro.dmg"
DOWNLOAD_DIR="$HOME/Downloads"
PYTHON_PKG_URL="https://www.python.org/ftp/python/3.12.13/python-3.12.13-macos11.pkg"

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

python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --upgrade pytesseract

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
    echo "Installing Python 3.12 (this needs your admin password)..."
    sudo installer -pkg "$PKG_DEST" -target /

    PYTHON_BIN_DIR="/Library/Frameworks/Python.framework/Versions/3.12/bin"
    export PATH="$PYTHON_BIN_DIR:$PATH"

    PYTHON_PATH_LINE="export PATH=\"$PYTHON_BIN_DIR:\$PATH\""
    if ! grep -Fq "$PYTHON_PATH_LINE" "$PROFILE_FILE" 2>/dev/null; then
        {
            echo
            echo "# Added by setup_macos_ocr.sh (Python 3.12)"
            echo "$PYTHON_PATH_LINE"
        } >> "$PROFILE_FILE"
    fi

    echo "Python 3.12 installed and added to PATH: $(python3 --version 2>/dev/null || echo 'restart terminal to confirm')"
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

case "$ARCH" in
    arm64)
        echo "Detected Apple Silicon (arm64)."

        install_python_if_missing

        echo "Downloading MacteabMacro.dmg..."
        warn_if_placeholder_url "$INTEL_ZIP_URL" "PLACEHOLDER"
        DEST="$DOWNLOAD_DIR/MacteabMacro.zip"
        curl -fL --progress-bar -o "$DEST" "$INTEL_ZIP_URL"
        echo "Downloaded to: $DEST"
        ;;
    x86_64)
        echo "Detected Intel (x86_64)."

        install_python_if_missing

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

echo "Installing required Python packages..."
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade \
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

echo "Python packages installed."
echo "Setup complete. Restart your terminal or run: source ~/.zprofile"