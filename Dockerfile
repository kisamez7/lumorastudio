# App (Next.js: UI + API + fila de tarefas + FFmpeg + Whisper local) — um container com disco persistente.
FROM node:22-bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates fontconfig && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
ENV NODE_ENV=production PORT=3000 STORAGE_DIR=/data/storage APP_MODE=hosted
VOLUME ["/data"]
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s CMD node -e "fetch('http://localhost:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["sh", "-c", "npx drizzle-kit push --dialect=postgresql --schema=./src/db/schema.ts --url=$DATABASE_URL --force && npm start"]
