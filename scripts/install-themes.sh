set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 || pwd)"
THEMES_SRC_DIR="${REPO_ROOT}/themes"

TIMESTAMP() {
  date +"%Y%m%dT%H%M%S" 2>/dev/null || echo "$(date +%s)"
}

print_usage() {
  cat <<EOF
Install Zed themes from this repository into your local Zed themes folder.

Usage:
  $0 [options]

Options:
  -y, --yes            Non-interactive: answer 'yes' to prompts (will overwrite).
  --dest DIR           Install to custom destination directory.
  --list               List theme files found in the repository.
  --help               Show this help message.

By default the script will try to detect your OS and install into:
  - Linux / macOS: \$HOME/.config/zed/themes
  - Windows (if \$APPDATA is set): \$APPDATA/Zed/themes

Example:
  $0 --dest \$HOME/.config/zed/themes
EOF
}


detect_default_dest() {
  if [ -n "${APPDATA:-}" ]; then
    printf "%s\n" "${APPDATA%/}/Zed/themes"
    return 0
  fi


  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    printf "%s\n" "${XDG_CONFIG_HOME%/}/zed/themes"
    return 0
  fi

  if [ -n "${HOME:-}" ]; then
    printf "%s\n" "${HOME%/}/.config/zed/themes"
    return 0
  fi


  printf "%s\n" "$(pwd)/.zed-themes"
}

list_theme_files() {
  (cd "${THEMES_SRC_DIR}" >/dev/null 2>&1 || exit 0)
  found=0
  for f in "${THEMES_SRC_DIR}"/zed-cursor-*.json; do
    [ -e "$f" ] || continue
    printf "%s\n" "$f"
    found=1
  done

  if [ "$found" -eq 0 ]; then
    printf "No zed-cursor-*.json files found in %s\n" "$THEMES_SRC_DIR"
  fi
}

confirm_yes() {
  # returns 0 if yes, 1 if no
  if [ "$ASSUME_YES" = "1" ]; then
    return 0
  fi

  printf "%s [y/N]: " "$1"
  read ans 2>/dev/null || return 1
  case "$ans" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

backup_and_copy() {
  src="$1"
  dest="$2"

  dest_dir="$(dirname "$dest")"
  if [ ! -d "$dest_dir" ]; then
    printf "Creating directory: %s\n" "$dest_dir"
    mkdir -p "$dest_dir" || {
      printf "Failed to create directory %s\n" "$dest_dir" >&2
      return 1
    }
  fi

  if [ -f "$dest" ]; then
    if [ "$ASSUME_YES" = "1" ]; then
      # create a timestamped backup
      bak="${dest}.$(TIMESTAMP).bak"
      printf "Backing up existing file %s -> %s\n" "$dest" "$bak"
      cp -p -- "$dest" "$bak" 2>/dev/null || cp -p "$dest" "$bak" 2>/dev/null || {
        printf "Warning: failed to create backup for %s\n" "$dest" >&2
      }
      printf "Overwriting %s\n" "$dest"
      cp -p -- "$src" "$dest" || {
        printf "Failed to copy %s -> %s\n" "$src" "$dest" >&2
        return 1
      }
    else
      if confirm_yes "File exists: $dest. Overwrite?"; then
        bak="${dest}.$(TIMESTAMP).bak"
        printf "Backing up existing file %s -> %s\n" "$dest" "$bak"
        cp -p -- "$dest" "$bak" 2>/dev/null || cp -p "$dest" "$bak" 2>/dev/null || {
          printf "Warning: failed to create backup for %s\n" "$dest" >&2
        }
        printf "Overwriting %s\n" "$dest"
        cp -p -- "$src" "$dest" || {
          printf "Failed to copy %s -> %s\n" "$src" "$dest" >&2
          return 1
        }
      else
        printf "Skipping %s\n" "$dest"
      fi
    fi
  else
    printf "Installing %s -> %s\n" "$src" "$dest"
    cp -p -- "$src" "$dest" || {
      printf "Failed to copy %s -> %s\n" "$src" "$dest" >&2
      return 1
    }
  fi

  return 0
}


ASSUME_YES=0
CUSTOM_DEST=""
LIST_ONLY=0


while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    --dest) CUSTOM_DEST="$2"; shift 2 ;;
    --dest=*) CUSTOM_DEST="${1#*=}"; shift ;;
    --list) LIST_ONLY=1; shift ;;
    --help|-h) print_usage; exit 0 ;;
    *) printf "Unknown arg: %s\n\n" "$1" >&2; print_usage; exit 2 ;;
  esac
done

if [ ! -d "${THEMES_SRC_DIR}" ]; then
  printf "Themes source directory not found: %s\n" "${THEMES_SRC_DIR}" >&2
  exit 1
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  list_theme_files
  exit 0
fi

DEST_DIR="${CUSTOM_DEST:-$(detect_default_dest)}"


printf "Source themes directory: %s\n" "${THEMES_SRC_DIR}"
printf "Destination (detected): %s\n" "${DEST_DIR}"
printf "\n"


set +e
src_files=
for f in "${THEMES_SRC_DIR}"/zed-cursor-*.json; do
  [ -e "$f" ] || continue
  src_files="${src_files} $f"
done
set -e

if [ -z "${src_files## }" ] || [ -z "$src_files" ]; then
  # If src_files is empty -> no matches
  printf "No zed-cursor-*.json theme files found in %s\n" "${THEMES_SRC_DIR}"
  exit 0
fi

printf "Found theme files to install:\n"
for f in $src_files; do
  printf "  - %s\n" "$f"
done
printf "\n"

if [ "$ASSUME_YES" != "1" ]; then
  if ! confirm_yes "Install the above files into ${DEST_DIR}?"; then
    printf "Aborted by user.\n"
    exit 0
  fi
fi


if [ ! -d "${DEST_DIR}" ]; then
  printf "Creating destination directory: %s\n" "${DEST_DIR}"
  mkdir -p "${DEST_DIR}" || {
    printf "Failed to create destination directory: %s\n" "${DEST_DIR}" >&2
    exit 1
  }
fi

for src in $src_files; do
  base="$(basename "$src")"
  dest="${DEST_DIR%/}/${base}"
  backup_and_copy "$src" "$dest" || {
    printf "Error installing %s\n" "$base" >&2
  }
done

printf "\nInstall complete. Themes installed to: %s\n" "${DEST_DIR}"
printf "Restart Zed or open the Theme Selector in Zed to pick the new themes.\n"
