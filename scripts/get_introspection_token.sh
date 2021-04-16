#!/usr/bin/env bash

TOKEN=$(curl -s -X POST 'https://dev-48174301.okta.com/oauth2/ausl7og2ga5Q3ksCo5d6/v1/token' \
       --header 'content-type: application/x-www-form-urlencoded'  \
      --data-urlencode 'client_id=0oal7k9csRqEwzuTM5d6' \
      --data-urlencode 'client_secret=hg9VlgPvH5y_ThWE7cHGSdNwhJ5QflXxuR6HHbTa'  \
      --data 'scope=groups' \
      --data-urlencode 'grant_type=client_credentials' | jq -r '.access_token')

echo $TOKEN

curl -v -H "Authorization: Bearer $TOKEN" https://api.kongcx.ninja/test
