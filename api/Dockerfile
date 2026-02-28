FROM node:22-slim AS app

WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi \
  && npm cache clean --force

COPY src ./src

RUN addgroup --system app && adduser --system --ingroup app app \
  && chown -R app:app /app
USER app

EXPOSE 3002

CMD ["node", "src/server.js"]
