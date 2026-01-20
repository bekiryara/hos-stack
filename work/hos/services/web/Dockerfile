FROM node:20-alpine AS build
WORKDIR /app

COPY services/web/package.json services/web/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY services/web/index.html ./index.html
COPY services/web/tsconfig.json ./tsconfig.json
COPY services/web/vite.config.ts ./vite.config.ts
COPY services/web/src ./src

RUN npm run build

FROM nginx:1.27-alpine
COPY services/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/ /usr/share/nginx/html/


