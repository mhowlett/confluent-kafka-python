#!/bin/bash

set -eu

PY_DOCKER_BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${PY_DOCKER_BIN}/../.env

# Wait for http service listener to come up and start serving
# $1 http service name
# $2 http service address
await_http() {
    local exit_code
    local attempt=0

    until curl ${2} || [[ ${attempt} -gt 5 ]]; do
        echo "awaiting $1..."
        let "attempt+=1"
        sleep 6
    done

    if [[ ${attempt} -lt 5 ]]; then
        return
    fi

    echo "$1 readiness test failed: aborting"
    exit 1
}

echo "Configuring Environment..."
source ${PY_DOCKER_SOURCE}/.env

echo "Generating SSL certs..."
${PY_DOCKER_BIN}/certify.sh

echo "Deploying cluster..."
docker-compose -f $PY_DOCKER_COMPOSE_FILE up -d

echo "Setting throttle for throttle test..."
docker-compose -f $PY_DOCKER_COMPOSE_FILE exec kafka sh -c "
        /usr/bin/kafka-configs  --bootstrap-server kafka:9092 \
                --alter --add-config 'producer_byte_rate=1,consumer_byte_rate=1,request_percentage=001' \
                --entity-name throttled_client --entity-type clients"

echo "Awaiting schema-registry..."
await_http "schema-registry" "http://localhost:8081"
echo ""

echo "Awaiting schema-registry-basic-auth..."
await_http "schema-registry-basic-auth" "http://localhost:8083"
echo ""
