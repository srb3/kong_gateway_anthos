#!/usr/bin/env bash

SERVICE_NAME="TestService"
ROUTE_NAME="TestRoute"

SERVICE_HOST="test-service.kong-hybrid-cp.svc.cluster.local"

KONG_ADMIN_API="$1"
KONG_PROXY="$2"

ACTION=${3:-create}

REDIS_HOST=""
REDIS_PORT="6379"

TOKEN="password"


function create() {

  # Add test service 
  echo "curl -s -k -X POST ${KONG_ADMIN_API}/services --data \"name=${SERVICE_NAME}\" --data 'url=http://${SERVICE_HOST}/get' -H \"Kong-Admin-Token:${TOKEN}\""
  curl -s -k -X POST ${KONG_ADMIN_API}/services --data "name=${SERVICE_NAME}" --data "url=http://${SERVICE_HOST}/get" -H "Kong-Admin-Token:${TOKEN}" |jq
  echo -e "\n"
  echo -e "\n"

  # Add test route
  echo "curl -s -k -X POST --url ${KONG_ADMIN_API}/services/${SERVICE_NAME}/routes --date \"name=${ROUTE_NAME}\"--data 'paths[]=/test' -H \"Kong-Admin-Token:${TOKEN}\""
  curl -s -k -X POST --url ${KONG_ADMIN_API}/services/${SERVICE_NAME}/routes --data "name=${ROUTE_NAME}" --data "paths[]=/test" -H "Kong-Admin-Token:${TOKEN}" | jq 
  echo -e "\n"
  echo -e "\n"

  # Add rate limit plugin
  echo -e "\
curl -s -k -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins \
--data \"name=rate-limiting\"  \
--data \"config.minute=10\" \
--data \"config.policy=redis\" \
--data \"config.redis_host=${REDIS_HOST}\" \
--data \"config.redis_port=${REDIS_PORT}\" \
-H \"Kong-Admin-Token:${TOKEN}\""
  curl -s -k -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins \
    --data "name=rate-limiting"  \
    --data "config.minute=10" \
    --data "config.policy=redis" \
    --data "config.redis_host=${REDIS_HOST}" \
    --data "config.redis_port=${REDIS_PORT}" \
    -H "Kong-Admin-Token:${TOKEN}" | jq
  echo -e "\n"
  echo -e "\n"

  sleep 5


}
function run_test() {
  for ((i=1;i<=20;i++)); do
    echo "curl -i -k ${KONG_PROXY}/test"
    curl -i -k ${KONG_PROXY}/test
    echo -e "\n"
  done
}
function clean() {
  rate_limit_plugin_id=$(curl -s -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins -H "Kong-Admin-Token:password" |  jq -r '.data[] | select(.name | contains("rate-limiting"))| .id')
  
   # Delete rate limit plugin
  echo "curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${rate_limit_plugin_id} -H \"Kong-Admin-Token:${TOKEN}\""
  curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${rate_limit_plugin_id} -H "Kong-Admin-Token:${TOKEN}"

  # Delete test route
  echo "curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME} -H \"Kong-Admin-Token:${TOKEN}\""
  curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME} -H "Kong-Admin-Token:${TOKEN}"

  # Delete test service
  echo "curl -i -X DELETE -k ${KONG_ADMIN_API}/services/${SERVICE_NAME} -H \"Kong-Admin-Token:${TOKEN}\""
  curl -i -X DELETE -k ${KONG_ADMIN_API}/services/${SERVICE_NAME} -H "Kong-Admin-Token:${TOKEN}"
}

if [ "${ACTION}" == "create" ]; then
  create
fi

if [ "${ACTION}" == "test" ]; then
  run_test
fi

if [ "${ACTION}" == "clean" ]; then
  clean  
fi
