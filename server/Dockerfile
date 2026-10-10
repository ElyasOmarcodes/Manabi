# Manabi server image. Provide GEMINI_API_KYA at runtime, never at build time:
#   docker run -p 8787:8787 -e GEMINI_API_KYA=... manabi-server
FROM node:22-alpine
WORKDIR /srv
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY src ./src
USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://127.0.0.1:8787/api/health >/dev/null || exit 1
CMD ["node", "src/index.mjs"]
