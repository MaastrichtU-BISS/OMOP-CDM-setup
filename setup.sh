# Build and start all services; the omop-init container downloads and loads the
# OMOP CDM structure and vocabulary on the first start (this can take a while).
# Add "--profile demo" to also seed the Eunomia demo data: ./setup.sh --profile demo
docker compose "$@" up -d --build
docker compose logs -f omop-init
