#!/usr/bin/env bash

# Proxy route auth with 'Introspection' flow

KONG_ADMIN_API="$1"
KONG_PROXY="$2"
CLIENT_ID="$3"
CLIENT_SECRET="$4"
AUTH_SERVER="$5"
ACTION=${6:-create}

TOKEN_PATH="v1/token"
INTROSPECTION_PATH="v1/introspect"
DISCOVERY_ENDPOINT="${AUTH_SERVER}/.well-known/openid-configuration"
TOKEN_ENDPOINT="${AUTH_SERVER}/${TOKEN_PATH}"
INTROSPECT_ENDPOINT="${AUTH_SERVER}/${INTROSPECTION_PATH}"

GRANT_TYPE="client_credentials"
SCOPE="customScope"
TOKEN_TYPE_HINT="access_token"

TOKEN="password"
SERVICE_NAME="TestService"
ROUTE_NAME="TestRoute" 
ROUTE_PATH="test"
SERVICE_HOST="test-service.kong-hybrid-cp.svc.cluster.local"

function create() {
  echo "\
curl -k -s -X POST ${KONG_ADMIN_API}/services \
--data \"name=${SERVICE_NAME}\" \
--data \"url=http://${SERVICE_HOST}/get\" \
-H \"Kong-Admin-Token:${TOKEN}\"
"

  curl -k -s -X POST ${KONG_ADMIN_API}/services \
    --data "name=${SERVICE_NAME}" \
    --data "url=http://${SERVICE_HOST}/get" \
    -H "Kong-Admin-Token:${TOKEN}"

  echo -e "\n"

  echo "\
curl -k -s -X POST ${KONG_ADMIN_API}/services/${SERVICE_NAME}/routes \
--data \"name=${ROUTE_NAME}\" \
--data \"paths[]=/test\" \
-H \"Kong-Admin-Token:${TOKEN}\"
"
  curl -k -s -X POST ${KONG_ADMIN_API}/services/${SERVICE_NAME}/routes \
    --data "name=${ROUTE_NAME}" \
    --data "paths[]=/test" \
    -H "Kong-Admin-Token:${TOKEN}"

  echo -e "\n"

  echo "\
curl -k -s -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins \
-H \"Kong-Admin-Token:${TOKEN}\" \
--data \"name=openid-connect\" \
--data \"config.auth_methods=introspection\"
--data \"config.introspection_endpoint=${INTROSPECT_ENDPOINT}\" \
--data \"config.issuer=${DISCOVERY_ENDPOINT}\" \
--data \"config.client_id=${CLIENT_ID}\" \
--data \"config.client_secret=${CLIENT_SECRET}\" \
--data \"config.scopes=customScope\"
"
  curl -k -s -X POST ${KONG_ADMIN_API}/routes/${ROUTE_NAME}/plugins \
    -H "Kong-Admin-Token:${TOKEN}" \
    --data "name=openid-connect" \
    --data "config.client_id=${CLIENT_ID}" \
    --data "config.client_secret=${CLIENT_SECRET}" \
    --data "config.issuer=${DISCOVERY_ENDPOINT}" \
    --data "config.scopes=customScope"

  echo -e "\n"

}

function run_test() {
  echo "curl -s -k ${KONG_PROXY}/test"
  curl -k -s ${KONG_PROXY}/test

  # For some reason the linux base64 function does not work for the auth header
  # AUTH_HEADER=$(echo "${CLIENT_ID}:${CLIENT_SECRET}" | base64 -w 0) 
  AUTH_HEADER=$(python -c "import base64; encoded = \
    base64.b64encode(b\"${CLIENT_ID}:${CLIENT_SECRET}\");\
    print(encoded.decode('utf-8'))")

  # Get access token
  echo -e "\
  curl -s -X POST ${TOKEN_ENDPOINT} \
-H \"Authorization: Basic ${AUTH_HEADER}\" \
--data \"grant_type=${GRANT_TYPE}\" \
--data \"scope=${SCOPE}\" | jq
"
  echo -e "\n"

  ACCESS_TOKEN=$(curl -s -X POST ${TOKEN_ENDPOINT} \
    -H "Authorization: Basic ${AUTH_HEADER}" \
    --data "grant_type=${GRANT_TYPE}" \
    --data "scope=${SCOPE}" | jq -r '.access_token')

  echo "access_token: ${ACCESS_TOKEN}"
  echo -e "\n"
  echo "curl -s -k ${KONG_PROXY}/test -H 'Authorization: Bearer ${ACCESS_TOKEN}'"
  curl -k -s ${KONG_PROXY}/test -H "Authorization: Bearer ${ACCESS_TOKEN}"
}

function clean() {

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
