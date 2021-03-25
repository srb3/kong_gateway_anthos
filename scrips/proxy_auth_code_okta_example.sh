#!/usr/bin/env bash

# Proxy route auth with 'Authorization Code' flow

KONG_ADMIN_API="$1"
KONG_PROXY="$2"

CLIENT_ID="$3"
CLIENT_SECRET="$4"
AUTH_SERVER="$5/.well-known/openid-configuration"

ACTION=${6:-create}

TOKEN="password"
SERVICE_NAME="TestService"
ROUTE_NAME="TestRoute" 
ROUTE_PATH="test"
SERVICE_HOST="test-service.kong-hybrid-cp.svc.cluster.local"
CONSUMER="xuser"
CONSUMER_ID="1e7bbede-8cea-11eb-9c00-18c04d05bc69"

function create() {
  curl -k -s -X POST ${KONG_ADMIN_API}/services \
    --data "name=${SERVICE_NAME}" \
    --data "url=http://${SERVICE_HOST}/get" \
    -H "Kong-Admin-Token:${TOKEN}"

  curl -k -s -X POST ${KONG_ADMIN_API}/services/${SERVICE_NAME}/routes \
    --data "name=${ROUTE_NAME}" \
    --data "paths[]=/test" \
    -H "Kong-Admin-Token:${TOKEN}"

  curl -k -s -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins \
    -H "Kong-Admin-Token:${TOKEN}" \
    --data "name=openid-connect" \
    --data "config.issuer=${AUTH_SERVER}" \
    --data "config.client_id=${CLIENT_ID}" \
    --data "config.client_secret=${CLIENT_SECRET}" \
    --data "config.redirect_uri=${KONG_PROXY}/${ROUTE_PATH}" \
    --data "config.scopes=openid" \
    --data "config.scopes=email" \
    --data "config.scopes=profile" \
    --data "config.scopes=employee_details" \
    --data "config.consumer_by=custom_id" \
    --data "config.consumer_claim=employeeNumber"

  oidc_plugin_id=$(curl -k -s ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins \
    -H "Kong-Admin-Token:${TOKEN}" | \
    jq -r '.data[] | select(.name | contains("openid-connect")) | .id')
  
  echo "${oidc_plugin_id}"

  curl -k -s -X POST ${KONG_ADMIN_API}/consumers/ \
    -H "Kong-Admin-Token:${TOKEN}" \
    --data "username=${CONSUMER}" \
    --data "custom_id=${CONSUMER_ID}"
}

function run_test() {
  echo "curl -s -k ${KONG_PROXY}/test"
  curl -vv -i -k -s ${KONG_PROXY}/test
}

function clean() {
  curl -k -s -X DELETE ${KONG_ADMIN_API}/consumers/${CONSUMER} -H "Kong-Admin-Token:${TOKEN}"

  oidc_plugin_id=$(curl -k -s ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins -H "Kong-Admin-Token:${TOKEN}" | jq -r '.data[] | select(.name | contains("openid-connect")) | .id')
  curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins/${oidc_plugin_id} -H "Kong-Admin-Token:${TOKEN}" 
  curl -i -X DELETE -k ${KONG_ADMIN_API}/routes/${ROUTE_NAME} -H "Kong-Admin-Token:${TOKEN}"
  curl -i -X DELETE -k ${KONG_ADMIN_API}/services/${SERVICE_NAME} -H "Kong-Admin-Token:${TOKEN}"

}

if [ "${ACTION}" == "create" ]; then
  create
elif [ "${ACTION}" == "test" ]; then
  run_test
elif [ "${ACTION}" == "clean" ]; then
  clean
fi
