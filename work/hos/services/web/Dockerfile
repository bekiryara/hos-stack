FROM node:20-alpine AS build-hos-web
WORKDIR /app

# Build context is ./work, so hos paths are hos/services/web/*
COPY hos/services/web/package.json hos/services/web/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY hos/services/web/index.html ./index.html
COPY hos/services/web/tsconfig.json ./tsconfig.json
COPY hos/services/web/vite.config.ts ./vite.config.ts
COPY hos/services/web/src ./src

RUN npm run build

FROM node:20-alpine AS build-marketplace
WORKDIR /app

# Build context is ./work, so marketplace-web is at marketplace-web/*
COPY marketplace-web/package.json marketplace-web/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY marketplace-web/vite.config.js ./vite.config.js
COPY marketplace-web/index.html ./index.html
COPY marketplace-web/src ./src

RUN npm run build

FROM nginx:1.27-alpine
COPY hos/services/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build-hos-web /app/dist/ /usr/share/nginx/html/
COPY --from=build-marketplace /app/dist/ /usr/share/nginx/html/marketplace/


