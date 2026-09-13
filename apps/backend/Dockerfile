FROM node:22-alpine

WORKDIR /app

# lockfile ごとコピーして npm ci にすることで、誰がいつビルドしても同じ版が入る。
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV NODE_ENV=production
EXPOSE 8080 4000

# node イメージに同梱の非 root ユーザーで動かす。
USER node

CMD ["node", "src/server.js"]
