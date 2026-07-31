FROM node:22-alpine AS base
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
COPY . .
# `prisma generate` only reads prisma/schema.prisma to emit the client — it
# never connects to a database. But prisma.config.ts eagerly resolves
# DATABASE_URL via env() just to load the config, so a placeholder is needed
# at build time even though it's never dialed. The real value is injected at
# `docker run` / compose time (this ENV doesn't survive into the final stage
# below, since Docker doesn't carry ENV across a new FROM).
ENV DATABASE_URL="postgresql://build:build@localhost:5432/build"
RUN npx prisma generate && npx tsc
RUN npm prune --production

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=base /app/dist ./dist
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/prisma ./prisma
COPY --from=base /app/prisma.config.ts ./
COPY --from=base /app/package.json ./
EXPOSE 3003
CMD ["node", "dist/infra/http/server.js"]
