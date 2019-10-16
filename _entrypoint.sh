#!/bin/bash
# Conjur Secret Retrieval for GitHub Action conjur-action

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            ' ') printf "%%20" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

create_pem() {
    # Create conjur_account.pem for valid SSL
    echo "$INPUT_CERTIFICATE" > conjur_"$INPUT_ACCOUNT".pem
}

conjur_authn() {
    if [[ -n "$INPUT_CERTIFICATE" ]]; then
        # Authenticate and receive session token from Conjur - encode Base64
        token=$(curl --cacert conjur_"$INPUT_ACCOUNT".pem --data "$INPUT_API_KEY" "$INPUT_URL"/authn/"$INPUT_ACCOUNT"/"$hostId"/authenticate | base64 | tr -d '\r\n')
    else
        # Authenticate and receive session token from Conjur - encode Base64
        token=$(curl -k --data "$INPUT_API_KEY" "$INPUT_URL"/authn/"$INPUT_ACCOUNT"/"$hostId"/authenticate | base64 | tr -d '\r\n')
    fi
}

array_secrets() {
    IFS=';'
    read -ra SECRETS <<< "$INPUT_SECRETS" # [0]=db/sqlusername | sql_username [1]=db/sql_password
}

set_secrets() {
    for secret in "${SECRETS[@]}"; do
        IFS='|'
        read -ra METADATA <<< "$secret" # [0]=db/sqlusername [1]=sql_username

        if [[ "${#METADATA[@]}" == 2 ]]; then
            secretId=$(urlencode "${METADATA[0]}")
            envVar=${METADATA[1]^^}
        else
            secretId=${METADATA[0]}
            IFS='/'
            read -ra SPLITSECRET <<< "$secretId" # [0]=db [1]=sql_password
            arrLength=${#SPLITSECRET[@]} # Get array length
            lastIndex=$((arrLength-1)) # Subtract one for last index
            envVar=${SPLITSECRET[$lastIndex]^^}
        fi

        if [[ -n "$INPUT_CERTIFICATE" ]]; then
            secretVal=$(curl --cacert conjur_"$INPUT_ACCOUNT".pem -H "Authorization: Token token=\"$token\"" "$INPUT_URL"/secrets/"$INPUT_ACCOUNT"/variable/"$secretId")
        else
            secretVal=$(curl -k -H "Authorization: Token token=\"$token\"" "$INPUT_URL"/secrets/"$INPUT_ACCOUNT"/variable/"$secretId")
        fi

        echo ::add-mask::"${secretVal}" # Masks the value in all logs & output
        echo ::set-env name="${envVar}"::"${secretVal}" # Set environment variable
    done
}

# URL-encode Host ID for future use
hostId=$(urlencode "$INPUT_HOST_ID")

create_pem()
conjur_authn()
# Secrets Example: db/sqlusername | sql_username; db/sql_password
array_secrets()
set_secrets()