# Runtime env: SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_ANON_KEY_FILE, APP_ENV. env.js is written at
# container start (docker/15-cs-console.envsh), not at build time.

FROM node:24.22.2-alpine@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85 AS build
WORKDIR /app
ENV CI=true NPM_CONFIG_UPDATE_NOTIFIER=false
COPY package.json package-lock.json .npmrc ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build && node scripts/precompress.mjs dist

FROM nginxinc/nginx-unprivileged:1.30.6-alpine@sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03
USER root
RUN apk upgrade --no-cache && rm -f /etc/nginx/conf.d/default.conf
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/templates/ /etc/nginx/templates/
COPY --chmod=0755 docker/15-cs-console.envsh /docker-entrypoint.d/15-cs-console.envsh
COPY --from=build /app/dist /usr/share/nginx/html
USER 101
ENV APP_ENV=production \
    NGINX_ENVSUBST_OUTPUT_DIR=/tmp/nginx/conf.d \
    NGINX_ENVSUBST_FILTER=^CS_
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
