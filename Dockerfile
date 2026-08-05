# syntax=docker/dockerfile:1
FROM node:20-slim AS base
# node:20-slim ships without OpenSSL. Prisma's query engine needs libssl at both
# `prisma generate` time (to pick the right engine binary) and runtime (to load it) —
# without this, generate silently guesses openssl-1.1.x and the engine fails to load
# with "libssl.so.1.1: cannot open shared object file".
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# ---- deps: install once, cached across builds unless package*.json changes ----
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci

# ---- builder: full Next.js build using the standalone output (next.config.js) ----
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* vars are inlined into the compiled output (client bundle AND server
# routes/middleware) at build time, not read at runtime — they MUST be the real public
# values here, not placeholders. This bit us once already: editing .env.local and
# restarting `next start` does nothing, because the value is already baked into
# .next/server/*.js by the time `next start` runs.
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}

RUN npm run build
# This project has no public/ assets yet; ensure the dir exists so the runner
# stage's COPY below doesn't fail if it's still absent.
RUN mkdir -p /app/public

# ---- runner: minimal image, only the standalone server output ----
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN groupadd --system --gid 1001 nodejs && useradd --system --uid 1001 --gid nodejs nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
# Next.js standalone tracing sometimes misses Prisma's generated engine binaries —
# copy them explicitly so the runtime PrismaClient can find them.
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/@prisma ./node_modules/@prisma

USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
