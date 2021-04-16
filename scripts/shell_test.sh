#!/usr/bin/env bash

NAMESPACE="kong-hybrid-cp"

SERVICE_NAME="TestService"
ROUTE_NAME="TestRoute"

SERVICE_HOST="test-service.kong-hybrid-cp.svc.cluster.local"

KONG_ADMIN_API="$1"
KONG_PROXY="$2"

ACTION=${3:-create}

REDIS_HOST="redis.${NAMESPACE}.svc.cluster.local"
REDIS_PORT="6379"
TOKEN="password"


DATADOG_HOST="datadog-statsd.${NAMESPACE}.svc.cluster.local"

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

  # Add datadog plugin
  echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/plugins/ \
--data \"name=datadog\"  \
--data \"config.host=${DATADOG_HOST}\" \
--data \"config.port=8125\" \
-H \"Kong-Admin-Token:${TOKEN}\"
  "
  curl -s -k -X POST ${KONG_ADMIN_API}/plugins/ \
    --data "name=datadog"  \
    --data "config.host=${DATADOG_HOST}" \
    --data "config.port=8125" \
    -H "Kong-Admin-Token:${TOKEN}" | jq
  echo -e "\n"
  echo -e "\n"

#  echo "\ 
#  curl -s -k -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins --data name=\"openid-connect\" \
#    --data config.issuer=\"https://******.okta.com/oauth2/********/.well-known/openid-configuration\" \
#    --data config.client_id=\"********\" \
#    --data config.client_secret=\"*********************\" \
#    --data config.redirect_uri=\"https://192.168.122.200:8443/test\" \
#    --data config.scopes=\"openid\" \
#    --data config.scopes=\"email\" \
#    --data config.scopes=\"profile\" \
#    -H \"Kong-Admin-Token:${TOKEN}\""
#  curl -s -k -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins --data name="openid-connect" \
#    --data config.issuer="https://********.okta.com/oauth2/**************/.well-known/openid-configuration" \
#    --data config.client_id="***************" \
#    --data config.client_secret="*******************************" \
#    --data config.redirect_uri="https://192.168.122.200:8443/test" \
#    --data config.scopes="openid" \
#    --data config.scopes="email" \
#    --data config.scopes="profile" \
#    -H "Kong-Admin-Token:${TOKEN}" | jq

  sleep 5
  for ((i=1;i<=20;i++)); do
    echo "curl -i -k ${KONG_PROXY}/test"
    curl -i -k ${KONG_PROXY}/test
    echo -e "\n"
  done

}

function clean() {
  datadog_plugin_id=$(curl -s -k ${KONG_ADMIN_API}/plugins -H "Kong-Admin-Token:password" |  jq -r '.data[] | select(.name | contains("datadog"))| .id')
  rate_limit_plugin_id=$(curl -s -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins -H "Kong-Admin-Token:password" |  jq -r '.data[] | select(.name | contains("rate-limiting"))| .id')
  openid_connect_plugin_id=$(curl -s -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins -H "Kong-Admin-Token:password" |  jq -r '.data[] | select(.name | contains("openid-connect"))| .id')
  
  # Delete datadog plugin
  echo "curl -i -X DELETE -k ${KONG_ADMIN_API}/plugins/${datadog_plugin_id} -H \"Kong-Admin-Token:${TOKEN}\""
  curl -i -X DELETE -k ${KONG_ADMIN_API}/plugins/${datadog_plugin_id} -H "Kong-Admin-Token:${TOKEN}"

  # Delete rate limit plugin
  echo "curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${rate_limit_plugin_id} -H \"Kong-Admin-Token:${TOKEN}\""
  curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${rate_limit_plugin_id} -H "Kong-Admin-Token:${TOKEN}"

  # Delete openid connect plugin
  #echo "curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${openid_connect_plugin_id} -H \"Kong-Admin-Token:${TOKEN}\""
  #curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${openid_connect_plugin_id} -H "Kong-Admin-Token:${TOKEN}"

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

if [ "${ACTION}" == "clean" ]; then
  clean  
fi
