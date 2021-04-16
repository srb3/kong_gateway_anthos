#!/usr/bin/env bash

# Kong manager groups RBAC Okta

KONG_ADMIN_API="$1"

# If authenticated_groups_claim is set
# then if the idp group of a user matches with a
# kong RBAC group the user will be automatically 
# given that RBAC group
QA_ADMIN_GROUP_NAME="kong_qa_admin"
QA_ADMIN_GROUP_COMMENT="kong QA admin group"
QA_ADMIN_WORKSPACE_ROLE="workspace-admin"

QA_WORKSPACE_NAME="qa"

QA_RO_GROUP_NAME="kong_qa_user"
QA_RO_GROUP_COMMENT="kong QA user group"

QA_RO_WORKSPACE_ROLE="workspace-read-only"

# we need to match what is returned by 
# consumer_claim field
# with what is found in the consumer_by field
# if consumer_claim is email
# and consumer_by is username
# then the username we set would need to match
# the email returned from the idp email claim
QA_ADMIN_WORKSPACE_USERNAME="dexp@mail.com"
QA_ADMIN_WORKSPACE_IN_ID="dexp@mail.com"
QA_ADMIN_WORKSPACE_EMAIL="dexp@mail.com"

QA_RO_WORKSPACE_USERNAME="mext@mail.com"
QA_RO_WORKSPACE_ID="mext@mail.com"
QA_RO_WORKSPACE_EMAIL="mext@mail.com"

ACTION=${2:-create}

TOKEN="password"

function create_roles() {
  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/ \
    -H "kong-admin-token: ${TOKEN}" \
    --data "name=workspace-read-only" \
    --data "comment=Read access to all endpoints in the workspace"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/ \
    -H "kong-admin-token: ${TOKEN}" \
    --data "name=workspace-super-admin" \
    --data "comment=Full access to all endpoints in the workspace"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/ \
    -H "kong-admin-token: ${TOKEN}" \
    --data "name=workspace-admin" \
    --data "comment=Full access to all endpoints in the workspace except RBAC Admin API"

  echo -e "\n"
  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/ \
    -H "kong-admin-token: ${TOKEN}" \
    --data "name=workspace-portal-admin" \
    --data "comment=Full access to Dev Portal related endpoints in the workspace"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-read-only/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=read" \
    --data "endpoint=*" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=*" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*/*/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-super-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=*" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=/developers" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=/developers/*" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=/files" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=/files/*" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=/kong" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=update,read" \
    --data "endpoint=workspaces/${QA_WORKSPACE_NAME}" \
    --data "negative=false"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*/*/*" \
    --data "negative=true"
  echo -e "\n"

  curl -s -k -X POST ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/workspace-portal-admin/endpoints \
    -H "kong-admin-token: ${TOKEN}" \
    --data "workspace=${QA_WORKSPACE_NAME}" \
    --data "actions=delete,create,update,read" \
    --data "endpoint=rbac/*/*/*/*/*" \
    --data "negative=true"
  echo -e "\n"
}

function create() {
  echo "\
  curl -s -k -X POST ${KONG_ADMIN_API}/workspaces \
    --data \"name=${QA_WORKSPACE_NAME}\" \
    -H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X POST ${KONG_ADMIN_API}/workspaces \
    --data "name=${QA_WORKSPACE_NAME}" \
    -H "kong-admin-token: ${TOKEN}"

  echo -e "\n"

  echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/groups \
--data \"comment=${QA_ADMIN_GROUP_COMMENT}\" \
--data \"name=${QA_ADMIN_GROUP_NAME}\" \
-H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X POST ${KONG_ADMIN_API}/groups \
    --data "comment=${QA_ADMIN_GROUP_COMMENT}" \
    --data "name=${QA_ADMIN_GROUP_NAME}" \
    -H "kong-admin-token: ${TOKEN}"

  echo -e "\n"

  echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/groups \
--data \"comment=${QA_RO_GROUP_COMMENT}\" \
--data \"name=${QA_RO_GROUP_NAME}\" \
-H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X POST ${KONG_ADMIN_API}/groups \
    --data "comment=${QA_RO_GROUP_COMMENT}" \
    --data "name=${QA_RO_GROUP_NAME}" \
    -H "kong-admin-token: ${TOKEN}"

  echo -e "\n"

  create_roles

  QA_ADMIN_ROLE_ID=$(curl -s -k ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/${QA_ADMIN_WORKSPACE_ROLE} \
    -H "Kong-Admin-Token: ${TOKEN}" | jq -r '.id')

  QA_RO_ROLE_ID=$(curl -s -k ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/${QA_RO_WORKSPACE_ROLE} \
    -H "Kong-Admin-Token: ${TOKEN}" | jq -r '.id')

  QA_WORKSPACE_ID=$(curl -s -k ${KONG_ADMIN_API}/workspaces/${QA_WORKSPACE_NAME} \
    -H "Kong-Admin-Token: ${TOKEN}" | jq -r '.id')

  echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/groups/${QA_ADMIN_GROUP_NAME}/roles \
-H \"kong-admin-token: ${TOKEN}\" \
--data \"rbac_role_id=${QA_ADMIN_ROLE_ID}\" \
--data \"workspace_id=${QA_WORKSPACE_ID}\"
"
curl -s -k -X POST ${KONG_ADMIN_API}/groups/${QA_ADMIN_GROUP_NAME}/roles \
   -H "Kong-Admin-Token: ${TOKEN}" \
   --data "rbac_role_id=${QA_ADMIN_ROLE_ID}" \
 	 --data "workspace_id=${QA_WORKSPACE_ID}"

  echo -e "\n"

  echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/groups/${QA_RO_GROUP_NAME}/roles \
-H \"kong-admin-token: ${TOKEN}\" \
--data \"rbac_role_id=${QA_RO_ROLE_ID}\" \
--data \"workspace_id=${QA_WORKSPACE_ID}\"
"
curl -s -k -X POST ${KONG_ADMIN_API}/groups/${QA_RO_GROUP_NAME}/roles \
   -H "Kong-Admin-Token: ${TOKEN}" \
   --data "rbac_role_id=${QA_RO_ROLE_ID}" \
 	 --data "workspace_id=${QA_WORKSPACE_ID}"

  echo -e "\n"
echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/admins \
-H "Kong-Admin-Token: ${TOKEN}" \
--data \"username=${QA_ADMIN_WORKSPACE_USERNAME}\" \
--data \"custom_id=${QA_ADMIN_WORKSPACE_ID}\" \
--data \"email=${QA_ADMIN_WORKSPACE_EMAIL}\" \
--data \"rbac_token_enabled=true\"
"

  curl -s -k -X POST ${KONG_ADMIN_API}/admins \
   -H "Kong-Admin-Token: ${TOKEN}" \
   --data "username=${QA_ADMIN_WORKSPACE_USERNAME}" \
   --data "custom_id=${QA_ADMIN_WORKSPACE_ID}" \
   --data "email=${QA_ADMIN_WORKSPACE_EMAIL}" \
   --data "rbac_token_enabled=true"

  echo -e "\n"

echo "\
curl -s -k -X POST ${KONG_ADMIN_API}/admins \
-H "Kong-Admin-Token: ${TOKEN}" \
--data \"username=${QA_RO_WORKSPACE_USERNAME}\" \
--data \"custom_id=${QA_RO_WORKSPACE_ID}\" \
--data \"email=${QA_RO_WORKSPACE_EMAIL}\" \
--data \"rbac_token_enabled=true\"
"

  curl -s -k -X POST ${KONG_ADMIN_API}/admins \
   -H "Kong-Admin-Token: ${TOKEN}" \
   --data "username=${QA_RO_WORKSPACE_USERNAME}" \
   --data "custom_id=${QA_RO_WORKSPACE_ID}" \
   --data "email=${QA_RO_WORKSPACE_EMAIL}" \
   --data "rbac_token_enabled=true"

  echo -e "\n"
}

function clean() {
  echo -e "Removing ${QA_ADMIN_WORKSPACE_USERNAME} workspace admin user\n"
echo "\
  curl -s -k -X DELETE ${KONG_ADMIN_API}/admins/${QA_ADMIN_WORKSPACE_USERNAME} \
    -H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X DELETE ${KONG_ADMIN_API}/admins/${QA_ADMIN_WORKSPACE_USERNAME} \
    -H "kong-admin-token: ${TOKEN}"
  echo -e "\n"

  echo -e "Removing ${QA_RO_WORKSPACE_USERNAME} workspace admin user\n"
echo "\
  curl -s -k -X DELETE ${KONG_ADMIN_API}/admins/${QA_RO_WORKSPACE_USERNAME} \
    -H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X DELETE ${KONG_ADMIN_API}/admins/${QA_RO_WORKSPACE_USERNAME} \
    -H "kong-admin-token: ${TOKEN}"
  echo -e "\n"
  echo -e "removing roles from ${QA_WORKSPACE_NAME} workspace\n"

  for i in $(curl -s -k ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles \
    -H "kong-admin-token: ${TOKEN}" | \
    jq -r '.data[].id')
    do
      curl -s -k -X DELETE ${KONG_ADMIN_API}/${QA_WORKSPACE_NAME}/rbac/roles/$i \
        -H "kong-admin-token: ${TOKEN}"
    done

  echo -e "\n"

  echo "\
  curl -s -k -X DELETE ${KONG_ADMIN_API}/workspaces/${QA_WORKSPACE_NAME} \
    -H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X DELETE ${KONG_ADMIN_API}/workspaces/${QA_WORKSPACE_NAME} \
    -H "kong-admin-token: ${TOKEN}"

  echo -e "\n"

  echo "\
curl -s -k -X DELETE ${KONG_ADMIN_API}/groups/${QA_ADMIN_GROUP_NAME} \
-H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X DELETE ${KONG_ADMIN_API}/groups/${QA_ADMIN_GROUP_NAME} \
    -H "kong-admin-token: ${TOKEN}"

  echo -e "\n"

  echo "\
curl -s -k -X DELETE ${KONG_ADMIN_API}/groups/${QA_RO_GROUP_NAME} \
-H \"kong-admin-token: ${TOKEN}\"
"
  curl -s -k -X DELETE ${KONG_ADMIN_API}/groups/${QA_RO_GROUP_NAME} \
    -H "kong-admin-token: ${TOKEN}"

  echo -e "\n"
}

if [ "${ACTION}" == "create" ]; then
  create
elif [ "${ACTION}" == "clean" ]; then
  clean
fi

# Tested with the following admin gui auth config
#{
#    "authenticated_groups_claim": ["groups"],
#    "auth_methods": ["authorization_code"],
#    "client_id": ["***************"],
#    "client_secret": ["***************************"],
#    "consumer_claim": ["email"],
#    "consumer_by": ["username","custom_id"],
#    "issuer": "https://dev-******.okta.com/oauth2/****************/.well-known/openid-configuration",
#    "login_redirect_uri": ["https://***/"],
#    "logout_methods": ["GET","DELETE","POST"],
#    "logout_query_arg": "logout",
#    "logout_redirect_uri": ["https://***/"],
#    "redirect_uri": ["https://***/"],
#    "scopes": ["openid","profile", "groups" ,"email", "offline_access"],
#    "session_cookie_name": "kong_manager_session",
#    "ssl_verify": false
#}
