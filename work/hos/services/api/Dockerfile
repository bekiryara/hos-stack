FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production

COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

COPY --chown=node:node services/api/src ./src
COPY --chown=node:node services/api/migrations ./migrations

EXPOSE 3000
USER node
CMD ["node", "src/index.js"]


