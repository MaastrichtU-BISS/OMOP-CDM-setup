# Build and start all services; the omop-init container downloads and loads the
# OMOP CDM structure and vocabulary on the first start (this can take a while).
# Pass "--profile demo" before this script's arguments to also seed demo data, e.g.:
#   COMPOSE_PROFILES=demo ./setup.sh
docker compose up -d --build "$@"
docker compose logs -f omop-init
