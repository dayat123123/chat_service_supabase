# Image operasional untuk migrate/seed/test-db/gen-keys/smoke/backup.
# Berisi bash, openssl, psql & pg_dump 17, pg_prove (pgTAP runner), curl, jq.
FROM alpine:3.22.7

RUN apk add --no-cache \
      bash \
      coreutils \
      curl \
      jq \
      openssl \
      perl \
      postgresql17-client \
 && apk add --no-cache --virtual .build-deps make perl-app-cpanminus \
 && cpanm --notest --quiet TAP::Parser::SourceHandler::pgTAP@3.37 \
 && apk del .build-deps \
 && rm -rf /root/.cpanm

ENTRYPOINT ["bash", "/olt/scripts/tools.sh"]
