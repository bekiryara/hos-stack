FROM node:20-alpine AS builder

WORKDIR /app

COPY services/api/package.json ./
RUN npm install --production

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY services/api ./services/api

WORKDIR /app/services/api

EXPOSE 3000

CMD ["node", "src/index.js"]

