#!/usr/bin/env bash
# Linux / macOS — inicia o Lumora Studio localmente (requer Node 20+ e PostgreSQL acessível em DATABASE_URL).
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || cp .env.example .env
set -a; . ./.env; set +a
command -v node >/dev/null || { echo "Instale o Node.js 20+"; exit 1; }
[ -d node_modules ] || npm install
npx drizzle-kit push --dialect=postgresql --schema=./src/db/schema.ts --url="$DATABASE_URL" --force
[ -d .next ] || npm run build
echo "Abrindo em http://localhost:${PORT:-3000}"
npm start
