#!/usr/bin/env bash

KONG_ADMIN_API="$1"

USERNAME="$2"
EMAIL="$3"

ACTION=${4:-create}

TOKEN="password"

TMP_PASS=$(openssl rand -base64 6)

function create() {

  curl -s -k -X POST ${KONG_ADMIN_API}/default/admins \
    -H "Kong-Admin-Token:${TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary @- << EOF
{
  "email":"${EMAIL}",
  "username":"${USERNAME}",
  "rbac_token_enabled":true
}
EOF
  echo -e "\n"

  user_id=$(curl -s -k -X GET "${KONG_ADMIN_API}/default/admins" -H "Kong-Admin-Token:password" | jq -r --arg USERNAME "$USERNAME"  '.data[] | select(.username | contains($USERNAME))| .id')
  echo -e "user_id: ${user_id}\n"
  curl -s -k -X POST "${KONG_ADMIN_API}/default/admins/${user_id}/roles" \
    -H "Kong-Admin-Token:${TOKEN}" \
    -H "Content-Type: application/json" \
    --data-raw '{"roles":"super-admin"}'

  echo -e "\n"

  reg_url=$(curl -s -k -X GET "${KONG_ADMIN_API}/default/admins/${user_id}?generate_register_url=true" -H "Kong-Admin-Token:${TOKEN}" | jq -r .register_url)
  echo -e "reg_url: ${reg_url}\n"
  reg_token=$(echo $reg_url | awk -F'token=' '{print $2}')
  echo -e "reg_token: ${reg_token}\n"

  curl -s -k -X POST "${KONG_ADMIN_API}/admins/register" \
    -H "Kong-Admin-Token:${TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary @- << EOF
{
  "email":"${EMAIL}",
  "username":"${USERNAME}",
  "password":"${TMP_PASS}",
  "token":"${reg_token}"
}
EOF
  echo -e "\n"

  curl -s -k -u ${USERNAME}:${PASSWORD} "${KONG_ADMIN_GUI}/"

  echo -e "\n"

  echo "USERNAME: ${USERNAME}"
  echo "EMAIL   : ${EMAIL}"
  echo "PASSWORD: ${TMP_PASS}"
}

function clean() {
  user_id=$(curl -s -k -X GET "${KONG_ADMIN_API}/default/admins" -H "Kong-Admin-Token:password" | jq -r --arg USERNAME "$USERNAME"  '.data[] | select(.username | contains($USERNAME))| .id')
  curl -s -k -X DELETE "${KONG_ADMIN_API}/default/admins/${user_id}" \
    -H "Kong-Admin-Token:${TOKEN}"
}

if [ "${ACTION}" == "create" ]; then
  create
fi

if [ "${ACTION}" == "clean" ]; then
  clean  
fi
