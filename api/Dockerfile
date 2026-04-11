# syntax=docker/dockerfile:1
FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install
COPY tsconfig.json ./
COPY src ./src
RUN npx tsc -p tsconfig.json && npm prune --omit=dev
EXPOSE 8080
ENV PORT=8080
CMD ["node", "dist/index.js"]
