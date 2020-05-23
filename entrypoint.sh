#!/bin/ash

LE_CERT=$1

: ${LE_EMAIL:?You must set the variable LE_EMAIL}
: ${LE_HTTP_PORT:?You must set the variable LE_HTTP_PORT}

if [ -z "${LE_STAGING}" ]; then
    LE_STAGING="false";
fi;

if [ -z "${LE_DRY_RUN}" ]; then
    LE_DRY_RUN="false";
fi;

toBool () {
    local BOOL=$(echo "${1}" | tr '[:upper:]' '[:lower:]')
    if [ "${BOOL}" == "true" ] || [ "${BOOL}" == "1" ] || [ "${BOOL}" == "yes" ] || [ "${BOOL}" == "y" ]; then
        echo "true"
    elif [ "${BOOL}" == "false" ] || [ "${BOOL}" == "0" ] || [ "${BOOL}" == "no" ] || [ "${BOOL}" == "n" ]; then
        echo "false"
    else
        echo "null"
    fi
}

calcStagingArg () {
    local STAGING_CERTS="${1}";
    local CERT_TO_CHECK="${2}";
    [[ -n "$(echo "${STAGING_CERTS}" | grep "\b${CERT_TO_CHECK}\b")" ]] && echo "--staging";
}

if [ "${LE_CERT}" == "" ]; then
   LE_CERT=$(ls /domains/); 
fi

LE_STAGING_BOOL=$(toBool "${LE_STAGING}");
LE_DRY_RUN_BOOL=$(toBool "${LE_DRY_RUN}");
LE_SHOW_COMMAND_BOOL=$(toBool "${LE_SHOW_COMMAND}");

if [ "${LE_STAGING_BOOL}" == "null" ]; then
     echo "Variable LE_STAGING does not contain boolean value: ${LE_STAGING}";
     echo "The value assumed to be a list of names of staging certificates."
     echo "Valid boolean values for true: 1, y, yes, true";
     echo "Valid boolean values for false: 0, n, no, false";
     echo "Empty value also means false and the values are case insensitive."
fi;

if [ "${LE_DRY_RUN_BOOL}" == "null" ]; then
     >&2 echo "Variable LE_DRY_RUN contains invalid value: ${LE_DRY_RUN}"
     >&2 echo "Valid boolean values for true: 1, y, yes, true";
     >&2 echo "Valid boolean values for false: 0, n, no, false";
     >&2 echo "Empty value also means false and the values are case insensitive."
     exit 1
fi;

if [ "${LE_SHOW_COMMAND_BOOL}" == "null" ]; then
     >&2 echo "Variable LE_SHOW_COMMAND contains invalid value: ${LE_SHOW_COMMAND}";
     >&2 echo "Valid boolean values for true: 1, y, yes, true";
     >&2 echo "Valid boolean values for false: 0, n, no, false";
     >&2 echo "Empty value also means false and the values are case insensitive."
     exit 1
fi;


STAGING_ARG=""
if [ "${LE_STAGING_BOOL}" == "true" ]; then
    STAGING_ARG="--staging";
fi;

DRY_RUN_ARG=""
if [ "${LE_DRY_RUN_BOOL}" == "true" ]; then
    DRY_RUN_ARG="--dry-run";
fi;

for LE_CERT_i in ${LE_CERT}
do
  DOMAINS=$(sed '/^$/d;s/[[:blank:]]//g' /domains/${LE_CERT_i} | sed ':a;N;$!ba;s/\s/ -d /g')
  if [ "${DOMAINS}" != "" ]; then
    if [ -z "${STAGING_ARG}" ]; then
        STAGING_ARG=$(calcStagingArg "${LE_STAGING}" "${LE_CERT_i}");
    fi;
    COMMAND='\
    certbot certonly '${STAGING_ARG}' '${DRY_RUN_ARG}' '${LE_EXTRA_OPTIONS}' \
      --expand \
      --email '${LE_EMAIL}' \
      --non-interactive \
      --agree-tos \
      --standalone \
      --preferred-challenges http-01 \
      --http-01-port '${LE_HTTP_PORT}' \
      --cert-name '${LE_CERT_i}' \
      -d '${DOMAINS}
      if [ "${LE_SHOW_COMMAND_BOOL}" == "true" ]; then
        echo "COMMAND:"
        echo "${COMMAND}"
      fi;
      eval "${COMMAND}"
  fi
done
