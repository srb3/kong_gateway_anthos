#!/usr/bin/env bash

TOKEN=$(curl -s -X POST 'https://******.okta.com/oauth2/ausl7og2ga5Q3ksCo5d6/v1/token' \
       --header 'content-type: application/x-www-form-urlencoded'  \
      --data-urlencode 'client_id=***********' \
      --data-urlencode 'client_secret=*********************'  \
      --data 'scope=groups' \
      --data-urlencode 'grant_type=client_credentials' | jq -r '.access_token')

echo $TOKEN

curl -v -H "Authorization: Bearer $TOKEN" https://<kong-api>/test
