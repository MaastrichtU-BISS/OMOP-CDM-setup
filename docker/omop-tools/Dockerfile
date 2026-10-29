FROM postgres:18

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY *.sh /usr/local/bin/
COPY sql /sql

ENTRYPOINT []
CMD ["init.sh"]
