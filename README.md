# Lumora.studio — estúdio de IA para vídeos

Plataforma web para **encontrar os melhores momentos de vídeos longos, criar cortes verticais de 60–90 s com hooks e legendas, editar, entender (resumo/transcrição/chat/mapa mental), baixar mídias autorizadas e preparar publicações** — com ferramentas de código aberto, processamento local e **sem marca d’água**.

> **Honestidade primeiro.** Este README separa o que está implementado e testado, o que depende de componentes opcionais e o que **não** existe. Nada é simulado.

## Arquitetura (o que foi realmente construído)

| Camada | Tecnologia | Papel |
|---|---|---|
| UI + API | **Next.js 16 (App Router) + TypeScript + Tailwind** | Interface, editor, rotas REST, SSE de progresso |
| Banco | **PostgreSQL + Drizzle ORM** | Projetos, ativos, transcrições, análises, cortes, tarefas, publicação, chat |
| Fila | Fila em processo (concorrência configurável) com estado no PostgreSQL | Progresso real, cancelamento (mata o FFmpeg/Whisper), recuperação de tarefas órfãs |
| Mídia | **FFmpeg/FFprobe** (binários via npm `ffmpeg-static`) | Metadados, análise, render H.264/AAC, legendas ASS (libass), áudio |
| Transcrição | **Whisper local** (transformers.js/ONNX, CPU) em processo filho | Palavras com tempo; fallback: importar SRT/VTT |
| LLM (opcional) | **Ollama** | Resumos redigidos, chat, hooks, tradução |
| Visão (opcional) | **`/backend` FastAPI + OpenCV** | Detecção automática de webcam (rostos estáveis) |
| Armazenamento | Disco/volume persistente (`STORAGE_DIR`) | Originais, cortes, áudios, capas |

> A especificação original pedia Python/FastAPI/Celery/Redis/Vite. Este projeto foi entregue em **Next.js full-stack** (ambiente de execução disponível). O serviço Python existe somente para Computer Vision. **Redis e Celery não são usados hoje** (a fila é em processo); `REDIS_URL` e o serviço Redis do compose estão reservados para escala horizontal. Driver S3 **não está implementado** (a interface `src/server/storage.ts` isola o acesso para trocá-lo).

## Como a IA seleciona os cortes (de verdade)

1. **Áudio (100% da duração):** energia RMS por segundo (FFmpeg → PCM 8 kHz em streaming).
2. **Imagem (100% da duração):** pontuação de mudança de quadro (FFmpeg `scene`) a 2 fps em 320 px → curva de movimento + cortes de cena; **refinamento adaptativo a 8 fps** apenas nas janelas escolhidas. *Não há modelo de visão semântico* (não “entende” objetos); isso é informado na UI.
3. **Fala:** transcrição Whisper (ou SRT importado) → sinais editoriais PT-BR (perguntas, exclamações, risadas, revelações, opinião, números, termos de jogo…).
4. **Seleção global:** todas as janelas de 60,5–89,5 s com início/fim em **frases completas/pausas** são pontuadas (interesse médio, pico, abertura, desfecho, densidade, coerência) e comparadas; supressão de sobreposição e repetição (Jaccard). **Nunca divide o vídeo em blocos sequenciais.**
5. **Nota 0–100** com 12 critérios e justificativa baseada em medições reais. É uma **estimativa heurística**, não prevê viralização.
6. **Duração 60–90 s validada** na seleção, em cada edição (API recusa), antes do render e **após o render com FFprobe** (arquivo fora do intervalo é descartado). Compilações são outro tipo, com duração livre.

## Hooks, legendas, reenquadramento
- **Hooks:** ≥ 3 opções por corte (Surpresa, Pergunta, Revelação, Curiosidade, Humor, Opinião, Desafio, Mistério). Com Ollama, o modelo recebe a transcrição e é instruído a não inventar; sem ele, frases-modelo usam apenas palavras/sinais reais do trecho. Ativos por padrão; editáveis (texto, tempo, duração, cor, fonte, animação, posição, remoção). Hooks e legendas coexistem.
- **Legendas:** 5 estilos (viral, podcast, dinâmico, minimalista, personalizado), destaque de palavra-chave, edição de texto/tempo, SRT.
- **Reenquadramento:** layouts **fit** (fundo desfocado), **A** (gameplay+webcam), **B** (webcam destacada), **C** (webcam em PiP), **D** (recorte 9:16 com keyframes suavizados). A região da webcam/jogo é marcada manualmente na UI ou detectada pelo serviço CV (`CV_SERVICE_URL`). Recortes mantêm proporção (sem deformar). Se a webcam já está embutida no vídeo, o sistema só recorta — **não reconstrói** a área do jogo coberta.

## Importação e download — política
- Upload MP4/MOV/MKV/WEBM com streaming para disco, FFprobe e limites de tamanho/duração.
- URLs **diretas** de mídia: download HTTP seguro (valida esquema/porta/credenciais, resolve DNS **e bloqueia IPs privados na conexão**, valida cada redirecionamento, limite de tamanho, cancelável, temporários limpos).
- **YouTube, TikTok, Instagram, Facebook, Twitch, Vimeo, X:** *sem importação direta*. Mostramos título/miniatura via oEmbed oficial quando existe e orientamos upload manual/API oficial. **Não contornamos DRM, login nem proteções, e não removemos marcas d’água.**
- Qualidades: só as reais do arquivo (nunca ampliamos). Imagens/slideshows ZIP **não** disponíveis.

## Executar localmente
```bash
cp .env.example .env        # ajuste DATABASE_URL
./start.sh                  # Linux/macOS   |   start.bat no Windows
```
Requisitos: Node 20+, PostgreSQL, ~2 GB livres para o modelo Whisper (baixado no 1º uso, precisa de internet). Opcional: Ollama (`OLLAMA_URL`), serviço CV (`docker compose up cv` ou `uvicorn` em `/backend`).

## Hospedagem
**Netlify/Vercel hospedam apenas a UI.** FFmpeg, Whisper e a fila **não podem** rodar em funções serverless (tempo/memória/disco efêmero). Padrão correto:
1. **Backend + workers + armazenamento:** `docker compose up -d` em uma VPS (Railway/Render/Fly.io com **volume persistente** também servem). Defina `APP_ACCESS_TOKEN` e `APP_MODE=hosted`; coloque atrás de HTTPS (Caddy/Traefik/Nginx + Let’s Encrypt).
2. **Frontend (opcional) no Netlify/Vercel:** defina `API_BASE_URL=https://api.seudominio.com` no painel e faça deploy (`netlify.toml` / `vercel.json` incluídos). `/api/*` é encaminhado ao backend. **Uploads grandes** não passam por proxies de Netlify/Vercel (limites de corpo): use o domínio do backend diretamente para enviar vídeos.
3. **PostgreSQL:** gerenciado (Neon/Supabase/RDS) ou o serviço `db` do compose; `DATABASE_URL`. **Redis:** reservado (não obrigatório hoje).
4. **Domínio/HTTPS:** aponte DNS A/CNAME para a VPS ou plataforma; certificados automáticos pelo proxy.
5. **Variáveis:** veja `.env.example`; nenhum segredo vai ao frontend (somente o servidor lê `process.env`).

**Custos:** o software é gratuito; hospedagem não. CPU para FFmpeg/Whisper, disco para vídeos e banda geram custo em VPS. No modo local o custo é o seu hardware.

## Segurança
SSRF (IP privado/redirecionamentos/porta), `execFile` sem shell, caminhos de storage sob raiz fixa com UUID, limites de upload, validação com FFprobe, `nosniff`, proxy de acesso com `APP_ACCESS_TOKEN` (rotas de upload validam o token no handler porque o proxy do Next limita corpos a 10 MB). **Não há contas de usuário**: o modo hospedado usa um código de acesso único; multiusuário exigiria autenticação real e isolamento por conta.

## Limitações conhecidas
- Sem modelo de visão semântico; “análise visual” = movimento/cortes de cena.
- Resumo/chat/hooks sem Ollama são **extrativos/heurísticos**; Tradução exige Ollama; dublagem/TTS e geração de vídeo por difusão **não existem** (o “Gerador de vídeos com IA” faz slides de texto).
- Separação de falantes e remoção de palavras de preenchimento: indisponíveis. Remoção de silêncio só no MP3 (alterar duração quebraria 60–90 s e a sincronia).
- Whisper `base` em CPU é lento para vídeos longos e menos preciso que modelos maiores (`WHISPER_MODEL`).
- Publicação automática não integrada (exportação/cópia manual). Efeitos sonoros: apenas mixagem de áudio enviado.
- Detecção de webcam precisa de rosto visível; caso contrário use a seleção manual.

Relatório de testes: [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md).
