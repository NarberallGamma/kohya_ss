#!/usr/bin/env bash
export VIRTUAL_ENV=.venv

env_var_exists() {
  if [[ -n "${!1}" ]]; then
    return 0
  else
    return 1
  fi
}

lib_path="/usr/lib/wsl/lib/"

if [ -d "$lib_path" ]; then
    if [ -z "${LD_LIBRARY_PATH}" ]; then
        export LD_LIBRARY_PATH="$lib_path"
    fi
fi

if [ -n "$SUDO_USER" ] || [ -n "$SUDO_COMMAND" ]; then
    echo "The sudo command resets the non-essential environment variables, we keep the LD_LIBRARY_PATH variable."
    export LD_LIBRARY_PATH=$(sudo -i printenv LD_LIBRARY_PATH)
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 1

# Check if --quiet is in the arguments
uv_quiet=""
uv_install_mode="${KOHYA_UV_INSTALL:-auto}"
args=()
for arg in "$@"; do
  case "$arg" in
    --quiet)
      uv_quiet="--quiet"
      ;;
    --install-uv)
      uv_install_mode="yes"
      ;;
    --no-install-uv)
      uv_install_mode="no"
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

if ! command -v uv &> /dev/null; then
  case "$uv_install_mode" in
    yes)
      curl -LsSf https://astral.sh/uv/install.sh | sh
      # shellcheck source=/dev/null
      source "$HOME/.local/bin/env"
      ;;
    no)
      echo "uv is not installed. Install uv manually or run with --install-uv." >&2
      exit 1
      ;;
    auto)
      if [[ -t 0 && -t 1 ]]; then
        read -r -p "uv is not installed. Attempt automatic installation now? [Y/n]: " install_uv
        if [[ "$install_uv" =~ ^[Yy]$ || -z "$install_uv" ]]; then
          curl -LsSf https://astral.sh/uv/install.sh | sh
          # shellcheck source=/dev/null
          source "$HOME/.local/bin/env"
        else
          echo "Install uv manually from https://astral.sh/uv and re-run this script." >&2
          exit 1
        fi
      else
        echo "uv is not installed and no TTY is available. Run with --install-uv or install uv manually." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown KOHYA_UV_INSTALL value: $uv_install_mode (expected auto, yes, no)" >&2
      exit 1
      ;;
  esac
fi

if [[ "$uv_quiet" == "--quiet" ]]; then
  echo "Notice: uv will run in quiet mode. No indication of the uv module download and install process will be displayed."
fi

git submodule update --init --recursive
uv run $uv_quiet kohya_gui.py --noverify "${args[@]}"
