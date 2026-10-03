#!/usr/bin/env bash
# Linux Docker launcher for Kohya GUI.
# Usage: ./run.sh help

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

cd "${REPO_ROOT}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Creating ${ENV_FILE} from .env.example"
  cp "${REPO_ROOT}/.env.example" "${ENV_FILE}"
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

mkdir -p \
  "${REPO_ROOT}/models" \
  "${REPO_ROOT}/dataset/images" \
  "${REPO_ROOT}/dataset/logs" \
  "${REPO_ROOT}/dataset/outputs" \
  "${REPO_ROOT}/dataset/regularization" \
  "${REPO_ROOT}/.cache/config" \
  "${REPO_ROOT}/.cache/user" \
  "${REPO_ROOT}/.cache/triton" \
  "${REPO_ROOT}/.cache/nv" \
  "${REPO_ROOT}/.cache/keras"

compose() {
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" --project-directory "${REPO_ROOT}" "$@"
}

ensure_sd_scripts() {
  if [[ ! -f "${REPO_ROOT}/sd-scripts/pyproject.toml" ]] && [[ ! -f "${REPO_ROOT}/sd-scripts/setup.py" ]]; then
    echo "sd-scripts is missing. From the repo root: git submodule update --init --recursive"
    exit 1
  fi
}

show_help() {
  cat <<EOF
Usage: ./run.sh <command>

Commands:
  help, -h, --help   Show this help
  up                 Start Kohya GUI in the background
  up-fg              Start Kohya GUI in the foreground
  up-all             Start Kohya GUI and TensorBoard
  down               Stop the stack
  restart            Restart Kohya GUI
  logs               Follow Kohya logs
  logs-tb            Follow TensorBoard logs
  ps                 Show container status
  build              Build the Kohya image

UI after up:
  Kohya        http://127.0.0.1:${KOHYA_PORT:-7861}/
  TensorBoard  http://127.0.0.1:${TENSORBOARD_PORT:-6006}/  (after up-all)

Models: ${MODELS_HOST_PATH:-./models}
Dataset: ./dataset
EOF
}

CMD="${1:-up}"

case "${CMD}" in
  help|-h|--help)
    show_help
    ;;
  up)
    ensure_sd_scripts
    compose up -d kohya-ss-gui
    echo "Kohya: http://127.0.0.1:${KOHYA_PORT:-7861}/"
    ;;
  up-fg)
    ensure_sd_scripts
    compose up --build kohya-ss-gui
    ;;
  up-all)
    ensure_sd_scripts
    compose --profile tensorboard up -d
    echo "Kohya:       http://127.0.0.1:${KOHYA_PORT:-7861}/"
    echo "TensorBoard: http://127.0.0.1:${TENSORBOARD_PORT:-6006}/"
    ;;
  down)
    compose --profile tensorboard down
    ;;
  restart)
    compose restart kohya-ss-gui
    ;;
  logs)
    compose logs -f kohya-ss-gui
    ;;
  logs-tb)
    compose --profile tensorboard logs -f tensorboard
    ;;
  ps)
    compose --profile tensorboard ps -a
    ;;
  build)
    ensure_sd_scripts
    compose build kohya-ss-gui
    ;;
  *)
    echo "Unknown command: ${CMD}"
    echo "Help: ./run.sh help"
    exit 1
    ;;
esac
