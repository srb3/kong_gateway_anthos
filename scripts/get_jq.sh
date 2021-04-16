#!/usr/bin/env bash

JQ_PATH=${1:-./jq}
JQ_URL=${2:-https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64}

if hash curl; then
  curl -L -s -o ${JQ_PATH} ${JQ_URL}
elif hash wget; then
  wget -q -O ${JQ_PATH} ${JQ_URL}
else
  echo "wget or curl needed to run"
fi

chmod +x ${JQ_PATH}
