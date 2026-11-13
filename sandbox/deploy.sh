#!/usr/bin/env bash
# ============================================================
#  Z.ai Bridge v2.3 — авто-сборка серверной части из шаблона
#
#  Копирует файлы из папки шаблона bridge_install/sandbox в
#  проект песочницы Next.js (структура шаблона повторяет
#  структуру проекта, расширение .txt отбрасывается).
#
#  Использование (из папки с шаблоном):
#    bash deploy.sh [ПУТЬ-К-ПРОЕКТУ]
#
#  ПУТЬ-К-ПРОЕКТУ — корень Next.js-проекта (где package.json).
#  Если не указан, предполагается, что шаблон лежит внутри
#  проекта как bridge_install/sandbox — корень найдётся сам.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Определяем корень проекта ---
PROJECT_DIR="${1:-}"
if [[ -z "$PROJECT_DIR" ]]; then
  candidate="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || true)"
  if [[ -n "$candidate" && -f "$candidate/package.json" ]]; then
    PROJECT_DIR="$candidate"
  fi
fi
if [[ -z "$PROJECT_DIR" ]]; then
  echo "ERROR: не удалось определить корень проекта." >&2
  echo "Запустите: bash deploy.sh /путь/к/проекту" >&2
  exit 1
fi
if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
  echo "ERROR: $PROJECT_DIR/package.json не найден — это не корень Next.js-проекта" >&2
  exit 1
fi

cd "$PROJECT_DIR"
echo "Проект: $PROJECT_DIR"

# 1) Копируем исходники из шаблона (src/**, .txt отбрасываем).
#    db.ts не трогаем, если он уже есть в проекте.
shopt -s globstar nullglob
copied=0
for f in "$SCRIPT_DIR"/src/**/*.txt; do
  rel="${f#"$SCRIPT_DIR"/}"      # напр. src/lib/bridge.ts.txt
  dest="${rel%.txt}"             # напр. src/lib/bridge.ts
  if [[ "$dest" == "src/lib/db.ts" && -f "$dest" ]]; then
    echo "SKIP (уже есть): $dest"
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$f" "$dest"
  copied=$((copied+1))
  echo "OK: $dest"
done

# 2) bridge-client/ — копии агента и установщика, которые сервер
#    раздаёт по GET /api/bridge/setup/ps1 и /setup/installer
mkdir -p bridge-client
cp "$SCRIPT_DIR/bridge-client/bridge.ps1.txt" bridge-client/bridge.ps1
cp "$SCRIPT_DIR/bridge-client/installer.template.bat.txt" bridge-client/installer.template.bat
echo "OK: bridge-client/bridge.ps1"
echo "OK: bridge-client/installer.template.bat"
copied=$((copied+2))

# 3) Модели Prisma (4 шт.) — добавляем к существующей схеме
mkdir -p prisma
if ! grep -q "model BridgeCommand" prisma/schema.prisma; then
  printf '\n' >> prisma/schema.prisma
  cat "$SCRIPT_DIR/prisma/schema.bridge.models.prisma.txt" >> prisma/schema.prisma
  echo "OK: 4 модели моста добавлены в prisma/schema.prisma"
else
  echo "SKIP: модели моста уже есть в schema.prisma"
fi

echo
echo "ГОТОВО: $copied файлов скопировано."
echo
echo "ДАЛЕЕ ВЫПОЛНИТЕ В КОРНЕ ПРОЕКТА:"
echo "  1) bun run db:push      — создать таблицы моста в SQLite"
echo "  2) перезапустить dev-сервер (если уже запущен)"
echo "  3) проверить: curl -s http://localhost:3000/api/bridge/status"
echo "     должно ответить {\"ok\":true,\"token\":\"...\",\"online\":false,...}"
