FROM node:22-alpine AS base

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile 2>/dev/null || pnpm install

COPY . .

# Development
FROM base AS dev
CMD ["pnpm", "dev"]

# Production
FROM base AS prod
RUN pnpm build
CMD ["pnpm", "start"]
