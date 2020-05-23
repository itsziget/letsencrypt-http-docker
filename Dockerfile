FROM certbot/certbot:v1.4.0

LABEL maintainer="Takács Ákos <rimelek@it-sziget.hu>"

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

ENV LE_EMAIL="" \
    LE_STAGING="false" \
    LE_DRY_RUN="false" \
    LE_HTTP_PORT="9080" \
    LE_EXTRA_OPTIONS="" \
    LE_SHOW_COMMAND="false"

ENTRYPOINT ["/entrypoint.sh"]
