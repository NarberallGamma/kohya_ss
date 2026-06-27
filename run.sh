#!/usr/bin/env bash
# Kohya_ss в Docker — сборка и запуск с обходом credsStore (как stable-diffusion-webui-docker).
#
# Перед первым запуском: создайте каталоги dataset/logs, dataset/outputs при необходимости
# (Docker при монтировании часто создаёт их сам).
#
# Пути в docker-compose.yaml:
#   - MODELS_HOST_PATH → чекпоинты и LoRA (общая папка с WebUI)
#   - ./dataset → датасеты обучения (например dataset/10_texas)
#
# Переменные: см. .env (KOHYA_PORT, MODELS_HOST_PATH, TENSORBOARD_PORT).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

DOCKER_CONFIG_DIR="${SCRIPT_DIR}/.docker-build"

if [[ ! -f "${DOCKER_CONFIG_DIR}/config.json" ]]; then
  echo "Создаём .docker-build/config.json (обход credsStore при docker build)"
  mkdir -p "$DOCKER_CONFIG_DIR"
  printf '%s\n' '{"auths":{},"currentContext":"default"}' > "${DOCKER_CONFIG_DIR}/config.json"
fi

export DOCKER_CONFIG="${DOCKER_CONFIG_DIR}"

compose() {
  docker compose "$@"
}

# Kohya зависит от git submodule kohya-ss/sd-scripts (pyproject внутри sd-scripts).
ensure_sd_scripts() {
  if [[ ! -f "${SCRIPT_DIR}/sd-scripts/pyproject.toml" ]] && [[ ! -f "${SCRIPT_DIR}/sd-scripts/setup.py" ]]; then
    echo "Ошибка: sd-scripts пуст или не клонирован." >&2
    echo "Выполните из корня репозитория:" >&2
    echo "  git submodule update --init --recursive" >&2
    exit 1
  fi
}

show_help() {
  cat <<'EOF'
Использование: ./run.sh <команда>

Команды:
  help, -h, --help   Показать эту справку

  build              Собрать образ kohya-ss-gui:local (долго при первом запуске)
  build-nc           То же с --no-cache

  up                 Запустить Kohya GUI в фоне (порт см. KOHYA_PORT в .env, по умолчанию 7861)
  up-fg              Запустить Kohya GUI в foreground (логи в терминале)
  up-all             Запустить Kohya + TensorBoard (профиль tensorboard)

  down               Остановить Kohya и TensorBoard (если были запущены)

  logs               Логи Kohya (follow)
  logs-tb            Логи TensorBoard (если запущен)

  ps                 Список контейнеров проекта

Пути (относительно этого репозитория):
  Модели WebUI:  MODELS_HOST_PATH в .env (по умолчанию ../stable-diffusion-webui-docker/data/models)
  Датасет:       ./dataset (например ./dataset/10_texas)
  Пресеты GUI:   ./presets  → /app/presets (user_presets/*.json для вкладки LoRA)
  Вывод LoRA:    ./dataset/outputs  → монтируется в /app/outputs; в GUI можно указать путь к Lora внутри /app/models

UI после up:
  Kohya: http://localhost:7861   (если KOHYA_PORT=7861)
  TensorBoard: http://localhost:6006  (после up-all)

Перед первым build (если клонировали без submodules):
  git submodule update --init --recursive

Примеры:
  ./run.sh build && ./run.sh up
  ./run.sh up-fg
  ./run.sh up-all
EOF
}

CMD="${1:-up}"

case "$CMD" in
  help|-h|--help)
    show_help
    ;;
  build)
    ensure_sd_scripts
    echo "Сборка с DOCKER_CONFIG=$DOCKER_CONFIG_DIR"
    compose build
    ;;
  build-nc)
    ensure_sd_scripts
    echo "Сборка --no-cache..."
    compose build --no-cache
    ;;
  up)
    compose up -d
    echo ""
    echo "Kohya GUI: http://localhost:${KOHYA_PORT:-7861}"
    echo "(порт из .env: KOHYA_PORT)"
    ;;
  up-fg)
    ensure_sd_scripts
    compose up --build
    ;;
  up-all)
    compose --profile tensorboard up -d
    echo ""
    echo "Kohya GUI: http://localhost:${KOHYA_PORT:-7861}"
    echo "TensorBoard: http://localhost:${TENSORBOARD_PORT:-6006}"
    ;;
  down)
    compose --profile tensorboard down
    ;;
  logs)
    compose logs -f kohya-ss-gui
    ;;
  logs-tb)
    compose logs -f tensorboard
    ;;
  ps)
    compose ps -a
    ;;
  *)
    echo "Неизвестная команда: $CMD"
    echo "Справка: ./run.sh help"
    exit 1
    ;;
esac
