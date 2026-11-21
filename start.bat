@echo off
REM Windows — inicia o Lumora Studio localmente (Node 20+ e PostgreSQL em DATABASE_URL).
cd /d %~dp0
if not exist .env copy .env.example .env
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /r "^DATABASE_URL=" .env`) do set DATABASE_URL=%%b
if not exist node_modules call npm install
call npx drizzle-kit push --dialect=postgresql --schema=./src/db/schema.ts --url=%DATABASE_URL% --force
if not exist .next call npm run build
echo Abrindo em http://localhost:3000
call npm start
