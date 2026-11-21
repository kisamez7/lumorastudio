import type { NextConfig } from "next";

const apiBase = (process.env.API_BASE_URL || "").replace(/\/$/, "");

const nextConfig: NextConfig = {
  // Binários nativos (FFmpeg/ffprobe) não podem ser empacotados pelo bundler.
  serverExternalPackages: ["ffmpeg-static", "@ffprobe-installer/ffprobe", "@huggingface/transformers", "onnxruntime-node"],
  poweredByHeader: false,
  // Modo hospedado dividido: frontend no Netlify/Vercel encaminha /api/* para o backend (container com FFmpeg/workers).
  // Observação: uploads grandes não devem passar por esse proxy (limites da plataforma) — veja README.
  async rewrites() {
    return apiBase ? [{ source: "/api/:path*", destination: `${apiBase}/api/:path*` }] : [];
  },
};

export default nextConfig;
