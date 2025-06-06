#!/bin/bash

source parameters.sh

REQUEST_TOKEN_FILE="token.txt"

ALWAYS_RENEW_TOKEN=false

# Iterate over every terminal command parameter:
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -rt)
            ALWAYS_RENEW_TOKEN=true
            ;;
        -e)
            if [[ -n "$2" ]]; then
                REQUEST_ENDPOINT="$2"
                REQUEST_DATA_FILE="payload_$2.json"
                shift
            else
                echo "ERROR: The parameter -e require an endpoint."
                exit 1
            fi
            ;;
        *)
            echo "ERRO: Invalid parameter: $1"
            ;;
    esac
    shift #Next parameter
done

echo -e "\n Initiating script to endpoint: $REQUEST_ENDPOINT"

REQUEST_DATA_FILE="payload_$REQUEST_ENDPOINT.json"

RESPONSE_DATA_FILE="response_$REQUEST_ENDPOINT.json"

if [ ! -f "$REQUEST_DATA_FILE" ]; then
    echo -e "\n Error: REQUEST_DATA_FILE ($REQUEST_DATA_FILE) not found."
    exit 1
fi


# Authentication ------- 

AUTH_DATA="grant_type=password&Username=$AUTH_USER&Password=$AUTH_PASS&scope=offline_access"
AUTH_CONTENT_TYPE="Content-Type: application/x-www-form-urlencoded"
AUTHBASIC="Authorization: Basic $AUTH_BASIC_TOKEN"
TOKEN_ORIGEM=""
TOKEN=""

if [ "$ALWAYS_RENEW_TOKEN" = true ] || [ ! -f "$REQUEST_TOKEN_FILE" ] || [ -z "$(tr -d '[:space:]' < "$REQUEST_TOKEN_FILE")" ]; then
    echo -e "\n Authenticating at: $AUTH_URL"
    RESPONSE=$(curl -k -s -X POST "$AUTH_URL" -H "$AUTH_CONTENT_TYPE" -H "$AUTHBASIC" -d "$AUTH_DATA")
    TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
    TOKEN_ORIGEM="Saving received TOKEN at: $REQUEST_TOKEN_FILE"
    echo "$TOKEN" > "$REQUEST_TOKEN_FILE"
else
    TOKEN=$(cat "$REQUEST_TOKEN_FILE")
    TOKEN_ORIGEM="Using TOKEN from file: $REQUEST_TOKEN_FILE"
fi

if [ -z "$TOKEN" ]; then
    echo -e "\n Authentication failed (1). Token not received. RESPONSE: "
    echo $RESPONSE
    exit 1
fi

echo -e "\n $TOKEN_ORIGEM"


# Request ------- 

CONTENT_TYPE="Content-Type: application/json"
ACCEPT_TYPE="Accept: application/json"
AUTHORIZATION="Authorization: Bearer $TOKEN"

API_URL="$REQUEST_DOMAIN/$REQUEST_ENDPOINT"

echo -e "\n Sending $REQUEST_DATA_FILE to: $API_URL"

RESPONSE=$(curl -k -s -w "%{http_code}" -X POST "$API_URL" -H "$CONTENT_TYPE" -H "$ACCEPT_TYPE" -H "$AUTHORIZATION" -d @"$REQUEST_DATA_FILE")

HTTPCODE="${RESPONSE: -3}"

if [ "$HTTPCODE" -eq 401 ]; then
    echo -e "\n Token expired! Authenticating at: \n $AUTH_URL "
    RESPONSE=$(curl -k -s -X POST "$AUTH_URL" -H "$AUTH_CONTENT_TYPE" -H "$AUTHBASIC" -d "$AUTH_DATA")
    TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

    echo -e "\n Saving received TOKEN at: $REQUEST_TOKEN_FILE"
    echo "$TOKEN" > "$REQUEST_TOKEN_FILE"

    if [ -z "$TOKEN" ]; then
        echo -e "\n Authentication failed (2). Token not received. RESPONSE: "
        echo $RESPONSE
        exit 1
    fi

    AUTHORIZATION="Authorization: Bearer $TOKEN"

    echo -e "\n Sending request again.."

    RESPONSE=$(curl -k -s -w "%{http_code}" -X POST "$API_URL" -H "$CONTENT_TYPE" -H "$AUTHORIZATION" -d @"$REQUEST_DATA_FILE")

    HTTPCODE="${RESPONSE: -3}"

    if [ "$HTTPCODE" -eq 401 ]; then
        echo -e "\n Authorization failed. RESPONSE: "
        echo "$RESPONSE"
        exit 1
    fi
fi

JSON="${RESPONSE:0:${#RESPONSE}-3}"

HTTPCODEMSG=$(grep "^$HTTPCODE " httpcodes.txt | cut -d ' ' -f2-)
if [ ! -n "$HTTPCODEMSG" ]; then
    HTTPCODEMSG="Unknown HTTP code:"
fi

echo -e "\n Response: [$HTTPCODE] $HTTPCODEMSG"

echo -e "$JSON" | sed 's/{/{\n  /g; s/}/\n}/g; s/,/, \n  /g; s/":"/": "/g; s/":"/": "/g'

echo "$JSON" | sed 's/{/{\n  /g; s/}/\n}/g; s/,/, \n  /g; s/":"/": "/g; s/":"/": "/g' > "$RESPONSE_DATA_FILE"
