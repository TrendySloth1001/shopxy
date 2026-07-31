FROM node:22-alpine AS deps
WORKDIR /app
# node:22-alpine bundles npm 10; pin to match local dev's npm 11 to cut down
# on version-skew surprises generally.
RUN npm install -g npm@11
COPY package*.json ./
# `npm install`, not `npm ci`: this tree's optional platform-specific WASM
# bindings (Tailwind v4 / lightningcss's @emnapi/* shims) resolve slightly
# differently depending on the host platform that last touched
# package-lock.json, which trips `npm ci`'s strict lockfile-sync check even
# on a lockfile that installs fine. `npm install` tolerates that drift.
RUN npm install

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# DOCKER_BUILD gates next.config.ts into `output: "standalone"` — a
# self-contained server bundle. Runtime env (API_BASE_URL, JWT cookie
# secret, etc.) is injected at `docker run` / compose time — see .env.example.
RUN DOCKER_BUILD=1 npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
COPY --from=builder --chown=nextjs:nodejs /app/.next-build/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next-build/static ./.next-build/static
USER nextjs
EXPOSE 3009
ENV PORT=3009
ENV HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
