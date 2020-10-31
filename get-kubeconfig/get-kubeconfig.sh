#!/bin/bash

progname=$0
if [ "$progname" != "bash" ]; then
    usage_progname=$progname
else
    usage_progname=get-kubeconfig
fi

SCRIPT_PARAMETERS=( $@ )
OPTS_CMD_LIST_SHORT="hor:c:t:k:u:l:s"
OPTS_CMD_LIST_LONG="help,overwrite,rancher-url:,cluster-name:,token-file:,ldap-file:,kubeconfig:,user-name:,skip-cleanup,rancher-token-ttl:,login-token-ttl:"
VERBOSITY=0
LOGIN_TOKEN=""

: "${RANCHER_URL:=rancher-url}"
: "${CLUSTER_NAME:=undefined}"
: "${USER_NAME:=undefined}"
: "${KUBECONFIG:=undefined}"
: "${TOKEN_FILE:=undefined}"
: "${LDAP_FILE:=undefined}"
: "${RANCHER_TOKEN:=undefined}"
: "${RANCHER_TOKEN_TTL:=0}"
: "${LOGIN_TOKEN_TTL:=60000}"
: "${OVERWRITE:=false}"
: "${LDAP_USER:=undefined}"
: "${LDAP_PWD:=undefined}"
: "${CLEANUP_EXPIRED_KEYS:=true}"

function usage()
{
   cat << HEREDOC

   Usage: $usage_progname ARGUMENTS

   required arguments:
     -r, --rancher-url                          specify the url for the related rancher-cluster                                      

     -c, --cluster-name                         specify the name of the k8s-cluster

     -t, --token-file                           specify the absolut path to the rancher-token-file

     or

     -l, --ldap-file                            specify the absolut path to the file with ldap-credentials
                                                (format: \$LDAP_USER:$\$LDAP_PWD)

     -k, --kubeconfig                           specify the absolut path to the kubeconfig-file, which
                                                will be generated
                                                (defaults to \$KUBECONFIG)

   optional arguments:
     -h, --help                                 show this help message and exit
     -u, --user-name                            specify the username for kubeconfig-creation
     --rancher-token-ttl                        specify in ms, if you want to generate an temporary token,
                                                especially interesting for ci-pipelines, TTL
                                                should be set to a value slightly above the estimated runtime
                                                of your pipeline. (defaults to 0 - permanent)
     --login-token-ttl                          specify in ms, if the runetime of KUBECONFIG-generation last
                                                longer than the default (defaults to 60000 - 1 min)
     -o, --overwrite                            specify, if you want to overwrite kubeconfig, if exists
     -s, --skip-cleanup                         specify, if you want to skip the cleanup of expired and oldest
                                                permanent keys

   example:
      $usage_progname \\
        --rancher-url https://rancher.de \\
        --cluster-name riplf-dev-k8s03 \\
        --token-file $(pwd)/token-file

HEREDOC
}

function log(){
        local log_message=$1
        local log_level=$2

        if [ -z "$log_level" ]; then
                log_level=INFO
        fi
        DATE=$(date '+%Y/%m/%d %H:%M:%S')
        if [ $VERBOSITY -ne -1 ]; then
            echo $DATE"|"$log_level"|get-kubeconfig|"$log_message
        fi
}

function exit_on_error_or_proceed(){

        local return_code=$1
        local log_message=$2
        local no_cleanup=$3
        local exit_code=$4

        : "${exit_code:=1}"
        : "${no_cleanup:=false}"


        if [ $return_code -ne 0 ]; then
                log "$log_message|nok" "ERROR"
                log "nok" "ERROR"
                exit $exit_code
        else
                log "$log_message|ok"
        fi
}

function check_rancher_url(){
    local log_text="check rancher url"

    log "$log_text|..."

    remove_trailing_slash "$RANCHER_URL"
    echo "$RANCHER_URL" | grep -q :// &> /dev/null
    if [ $? -ne 0 ]; then
        RANCHER_URL="https://$RANCHER_URL"
    fi

    log "$log_text|$RANCHER_URL"
    log "$log_text|ok"
}

function remove_trailing_slash(){
    RANCHER_URL=$(echo $1 | sed 's:/*$::')
}

function check_user_name(){
    local log_text="check username"
    local return_code=0

    log "$log_text|..."

    if [ "$USER_NAME" == "undefined" ]; then
        echo "$RANCHER_TOKEN" | grep -q "kubeconfig-u-\|token-" &> /dev/null
        if [ $? -eq 0 ]; then
            USER_NAME=$(echo "$RANCHER_TOKEN" | cut -d: -f1)
            if [ "$USER_NAME" == "" ]; then
                log "$log_text|USER_NAME is empty" "ERROR"
                return_code=1
            fi
        else
            USER_NAME=$(whoami)
        fi
    fi

    if [ $return_code -eq 0 ]; then
        log "$log_text|$USER_NAME"
    fi
    exit_on_error_or_proceed $return_code "$log_text"
}

function get_login_token(){
    local log_text="$1" return_code return_value loop_start=1 loop_max=3
    local data=''
    log "$log_text|get login token|..."
    LDAP_PWD=$(echo "$LDAP_PWD" | sed -e 's/\\/\\\\/g' -e 's/\"/\\\"/g' )
    for ((try=$loop_start;try<=$loop_max;try++)); do
        LOGIN_TOKEN=""
        log "$log_text|get login token|try ${try}/$loop_max|..."
        data=$(echo "{
                                    \"description\": \"get-kubeconfig login-token\",
                                    \"labels\": {
                                    \"ui-session\": \"true\"
                                    },
                                    \"password\": \"$LDAP_PWD\",
                                    \"responseType\":\"json\",
                                    \"ttl\":$LOGIN_TOKEN_TTL,
                                    \"username\":\"$LDAP_USER\"
                            }")

        return_value=$(curl -s -X POST \
                            -H 'Accept: application/json' \
                            -H 'Content-Type: application/json' \
                            -d "$data" \
                            $RANCHER_URL/v3-public/openLdapProviders/openldap?action=login 2>&1 )
        return_code=$?
        if [ $return_code -ne 0 ]; then
            log "$log_text|get login token|try ${try}/$loop_max|curl ended with an error ($return_value)" "ERROR"
            log "$log_text|get login token|try ${try}/$loop_max|nok" "ERROR"
            continue
        fi

        LOGIN_TOKEN=$(echo "$return_value" | jq -r ' select(.token != null) | .token ' 2>&1)
        return_code=$?
        if [ $return_code -ne 0 ]; then
            log "$log_text|get login token|try ${try}/$loop_max|error ($LOGIN_TOKEN) on extracting token from response ($return_value)" "ERROR"
            log "$log_text|get login token|try ${try}/$loop_max|nok" "ERROR"
            continue
        fi

        if [ "$LOGIN_TOKEN" == "" ]; then
            error_msg=$( echo "$return_value" | jq -r ' select( (.code != null) and (.type != null) and (.message != null) ) | select(.type == "error" ) | .code+"|"+.message ' 2>&1 )
            if [[ "$error_msg" =~ .*Unauthorized.* ]]; then
                log "$log_text|get login token|try ${try}/$loop_max|${error_msg//*|/}" "ERROR"
                log "$log_text|get login token|try ${try}/$loop_max|nok" "ERROR"
                log "$log_text|get login token|nok" "ERROR"
                return 1
            fi

            log "$log_text|get login token|try ${try}/$loop_max|LOGIN_TOKEN is empty, response ($return_value)" "ERROR"
            log "$log_text|get login token|try ${try}/$loop_max|nok" "ERROR"
            continue
        fi

        log "$log_text|get login token|try ${try}/$loop_max|ok"
        log "$log_text|get login token|ok"
        return 0
    done

    log "$log_text|get login token|nok" "ERROR"
    return 1
}

function get_rancher_token () {
    local log_text="$1" return_code return_value loop_start=1 loop_max=3 ttl_msg=" "

    log "$log_text|get rancher token|..."

    if [ $RANCHER_TOKEN_TTL -gt 0 ]; then
        ttl_msg=" temporary "
    fi

    for ((try=$loop_start;try<=$loop_max;try++)); do
        RANCHER_TOKEN=""
        log "$log_text|get rancher token|try ${try}/$loop_max|..."
        return_value=$(curl -s \
                        -H 'content-type: application/json' \
                        -H "Authorization: Bearer $LOGIN_TOKEN" \
                        -d '{
                              "type": "token",
                              "ttl": '$RANCHER_TOKEN_TTL',
                              "description": "get-kubeconfig'"$ttl_msg"'token"
                        }' \
                        $RANCHER_URL/v3/token 2>&1 )

        return_code=$?
        if [ $return_code -ne 0 ]; then
            log "$log_text|get rancher token|try ${try}/$loop_max|curl ended with an error, $return_value" "ERROR"
            log "$log_text|get rancher token|try ${try}/$loop_max|nok" "ERROR"
            continue
        fi

        RANCHER_TOKEN=$(echo "$return_value" | jq -r ' select(.token != null) | .token ' 2>&1)
        return_code=$?
        if [ $return_code -ne 0 ]; then
            log "$log_text|get rancher token|try ${try}/$loop_max|error ($RANCHER_TOKEN) on extracting token from response ($return_value)" "ERROR"
            log "$log_text|get rancher token|try ${try}/$loop_max|nok" "ERROR"
            continue
        fi

        if [ "$LOGIN_TOKEN" == "" ]; then
            log "$log_text|get rancher token|try ${try}/$loop_max|RANCHER_TOKEN is empty, response (return_value)" "ERROR"
            log "$log_text|get rancher token|try ${try}/$loop_max|nok" "ERROR"
            continue
        fi

        log "$log_text|get rancher token|try ${try}/$loop_max|ok"
        log "$log_text|get rancher token|ok"
        return 0
    done

    log "$log_text|get rancher token|nok" "ERROR"
    return 1
}

function get_ldap_credentials () {
    local log_text="$1"

    log "$log_text|get ldap credentials|..."

    if [ "$LDAP_USER" != "undefined" ] && [ "$LDAP_PWD" != "undefined" ]; then
        log "$log_text|get ldap credentials|ldap-credentials were given through environment-variables"
        log "$log_text|get ldap credentials|ok"
        return 0
    fi

    if [ "$LDAP_FILE" == "undefined" ]; then
        log "$log_text|get ldap credentials|no LDAP_FILE or LDAP_USER/LDAP_PWD were given" "ERROR"
        log "$log_text|get ldap credentials|nok" "ERROR"
        return 1
    fi

    LDAP_FILE=$(readlink -f "$LDAP_FILE")
    if [ ! -r "$LDAP_FILE" ]; then
        log "$log_text|get ldap credentials|$LDAP_FILE does not exist or no read permissions were granted" "ERROR"
        log "$log_text|get ldap credentials|nok" "ERROR"
        return 1
    fi

    ldap_file_string=$(cat $LDAP_FILE)
    if [ "$ldap_file_string" == "" ]; then
        log "$log_text|get ldap credentials|$LDAP_FILE is empty, must contain credentials with format LDAP_USER:LDAP_PWD" "ERROR"
        log "$log_text|get ldap credentials|nok" "ERROR"
        return 1
    fi

    LDAP_USER=${ldap_file_string%%:*}
    LDAP_PWD=${ldap_file_string#*:}
    if [ "$LDAP_USER" == "" ] || [ "$LDAP_PWD" == "" ]; then
        log "$log_text|get ldap credentials|no LDAP_FILE or LDAP_USER/LDAP_PWD were given" "ERROR"
        log "$log_text|get ldap credentials|nok" "ERROR"
        return 1
    fi

    log "$log_text|get ldap credentials|ldap-credentials were given by ldap-file $LDAP_FILE"
    log "$log_text|get ldap credentials|ok"
}

function get_token(){
    local log_text="get token" ldap_file_string="" rancher_token="" return_code=0

    log "$log_text|..."

    if [ "$RANCHER_TOKEN" != "undefined" ]; then
        log "$log_text|token were given by environemnt variable RANCHER_TOKEN"
        log "$log_text|ok"
        return 0
    fi

    if [ "$TOKEN_FILE" != "undefined" ]; then
        log "$log_text|read token from token-file $TOKEN_FILE|..."
        TOKEN_FILE=$(readlink -f "$TOKEN_FILE")
        if [ ! -r "$TOKEN_FILE" ]; then
            log "$log_text|$TOKEN_FILE does not exist or no read permissions were granted" "ERROR"
            exit_on_error_or_proceed 1 "$log_text"
        fi

        RANCHER_TOKEN=$(cat "$TOKEN_FILE" 2>&1)
        return_code=$?
        if [ $return_code -ne 0 ]; then
            log "$log_text|error while reading $TOKEN_FILE, $RANCHER_TOKEN" "ERROR"
            exit_on_error_or_proceed $return_code "$log_text"
        fi

        if [ "$RANCHER_TOKEN" == "" ]; then
            log "$log_text|RANCHER_TOKEN is empty" "ERROR"
            exit_on_error_or_proceed 1 "$log_text"
        fi

        log "$log_text|read token from token-file  $TOKEN_FILE|ok"
        log "$log_text|ok"

        return 0
    fi

    log "$log_text|trying to get rancher-token by ldap|..."

    get_ldap_credentials "$log_text|trying to get rancher-token by ldap"
    if [ $? -ne 0 ]; then
        log "$log_text|trying to get rancher-token by ldap|nok" "ERROR"
        exit_on_error_or_proceed 1 "$log_text"
    fi

    get_login_token "$log_text|trying to get rancher-token by ldap"
    if [ $? -ne 0 ]; then
        log "$log_text|trying to get rancher-token by ldap|nok" "ERROR"
        exit_on_error_or_proceed 1 "$log_text"
    fi

    get_rancher_token "$log_text|trying to get rancher-token by ldap"
    if [ $? -ne 0 ]; then
        log "$log_text|trying to get rancher-token by ldap|nok" "ERROR"
        exit_on_error_or_proceed 1 "$log_text"
    fi

    log "$log_text|trying to get rancher-token by ldap|ok"
}

function get_cluster_id(){
    local log_text="get cluster id by name $CLUSTER_NAME"
    local return_code=0

    log "$log_text|..."

    return_value_id=$(curl -s "$RANCHER_URL/v3/clusters" \
                     -H 'content-type: application/json' \
                     -H "Authorization: Bearer $RANCHER_TOKEN" \
                     2>&1)

    return_code=$?
    if [ $return_code -eq 0 ]; then
        CLUSTER_ID=$(echo "$return_value_id" | jq -r '.data[] | select(.name=="'$CLUSTER_NAME'") | .id' 2>&1)
        return_code=$?
        if [ $return_code -eq 0 ]; then
            if [ "$CLUSTER_ID" != "" ]; then
                log "$log_text|$CLUSTER_ID"
            else
                log "$log_text|CLUSTER_ID is empty" "ERROR"
                return_code=1
            fi
        else
            log "$log_text|error while extracting cluster-id ($CLUSTER_ID)" "ERROR"
            log "$log_text|response ($return_value_id)" "ERROR"
            return_code=1
        fi
    else
        log "$log_text|$return_value_id" "ERROR"
    fi
    exit_on_error_or_proceed $return_code "$log_text"
}

function write_kubeconfig(){
    local kube_config=$(readlink -f "$KUBECONFIG")
    local log_text="generate kubeconfig"
    local return_code=0

    log "$log_text|..."

    if [ -f "$kube_config" ]; then
        log "$log_text|$kube_config already exists!" "WARNING"
        if [ "$OVERWRITE" == "false" ]; then
            log "$log_text|if you want to overwrite it, please specify parameter -o / --overwrite" "ERROR"
            exit_on_error_or_proceed 1 "$log_text"
        else
            log "$log_text|create backup ${kube_config}.bak|..."
            return_value=$(cp -f $kube_config ${kube_config}.bak 2>&1)
            return_code=$?
            if [ $return_code -eq 0 ]; then
                log "$log_text|create backup ${kube_config}.bak|ok"
            else
                log "$log_text|create backup ${kube_config}.bak|nok, $return_value" "ERROR"
                exit_on_error_or_proceed $return_code "$log_text"
            fi
        fi
    fi

    log "$log_text|write file $kube_config|..."
    return_value=$(cat <<EOF > $kube_config

apiVersion: v1
kind: Config
clusters:
- name: "$CLUSTER_NAME"
  cluster:
    server: "$RANCHER_URL/k8s/clusters/$CLUSTER_ID"
    api-version: v1

users:
- name: "$USER_NAME"
  user:
    token: "$RANCHER_TOKEN"

contexts:
- name: "$CLUSTER_NAME"
  context:
    user: "$USER_NAME"
    cluster: "$CLUSTER_NAME"

current-context: "$CLUSTER_NAME"
EOF
    2>&1 )
    return_code=$?
    if [ $return_code -eq 0 ]; then
        log "$log_text|write file $kube_config|ok"
    else
        log "$log_text|write file $kube_config|nok, $return_value" "ERROR"
    fi

    exit_on_error_or_proceed $return_code "$log_text"
}

function cleanup_expired_keys(){
    local log_text="cleanup expired keys"
    local keys=()
    local expired_keys=()
    local permanent_keys=()

    log "$log_text|..."
    if [ "$CLEANUP_EXPIRED_KEYS" != "true" ]; then
        log "$log_text|skipping cleanup by parameter --skip-cleanup"
        log "$log_text|ok"
        return 0
    fi
    log "$log_text|get keys|..."
    return_value=$(curl -s \
                        -H 'content-type: application/json' \
                        -H "Authorization: Bearer $RANCHER_TOKEN" \
                        $RANCHER_URL/v3/tokens 2>&1 )
    return_code=$?
    if [ $return_code -eq 0 ]; then
        keys=( $(echo "$return_value" | jq -r '.data[] | select(.description | startswith("get-kubeconfig")) | .name ' 2>&1 ) )
        return_code=$?
        if [ $return_code -eq 0 ]; then
            if [ ${#keys[@]} -gt 0 ]; then
                log "$log_text|get keys|ok"
                log "$log_text|extract expired keys|..."
                expired_keys=( $(echo "$return_value" | jq -r '.data[] | select(.expired == true and (.description | startswith("get-kubeconfig"))) | .name ' 2>&1 ) )
                return_code=$?
                if [ $return_code -eq 0 ]; then
                    if [ ${#expired_keys[@]} -gt 0 ]; then
                    log "$log_text|extract expired keys|$(IFS=','; echo "${expired_keys[*]}")"
                    else
                    log "$log_text|extract expired keys|no expired keys found"
                    fi
                    log "$log_text|extract expired keys|ok"
                else
                    log "$log_text|extract expired keys|error while extracting expired keys($return_value)" "ERROR"
                    exit_on_error_or_proceed $return_code "$log_text"
                fi

                log "$log_text|extract permanent keys and ignore 5 newest|..."
                permanent_keys=( $(echo "$return_value" | jq -r '.data | sort_by(.created) | .[] | select(.expiresAt == "" and (.description | startswith("get-kubeconfig"))) | .name' | head -n-5 2>&1 ) )
                return_code=$?
                if [ $return_code -eq 0 ]; then
                    if [ ${#permanent_keys[@]} -gt 0 ]; then
                    log "$log_text|extract permanent keys and ignore 5 newest|$(IFS=','; echo "${permanent_keys[*]}")"
                    else
                    log "$log_text|extract permanent keys and ignore 5 newest|no permanent keys found"
                    fi
                    log "$log_text|extract permanent keys and ignore 5 newest|ok"
                else
                    log "$log_text|extract permanent keys and ignore 5 newest|error while extracting permanent keys($return_value)" "ERROR"
                    exit_on_error_or_proceed $return_code "$log_text"
                fi
            fi
        else
              log "$log_text|get keys|error while extracting keys($keys)" "ERROR"
              exit_on_error_or_proceed $return_code "$log_text"
        fi
    else
        log "$log_text|get keys|nok, $return_value" "ERROR"
    fi

    if [ $return_code -eq 0 ]; then
        for key in "${expired_keys[@]}" "${permanent_keys[@]}"; do
            log "$log_text|delete extracted key $key|..."
            http_return_code=$(curl -s \
                                -X DELETE \
                                -Lw "%{http_code}\\n" \
                                -o /dev/null \
                                -H 'content-type: application/json' \
                                -H "Authorization: Bearer $RANCHER_TOKEN" \
                                $RANCHER_URL/v3/tokens/$key 2>&1 )
            return_code=$?
            if [ $return_code -eq 0 ]; then
                    if [ "$http_return_code" == "204" ]; then
                            log "$log_text|delete extracted key $key|ok"
                    else
                            log "$log_text|delete extracted key $key|http-code: $http_return_code" "ERROR"
                            log "$log_text|delete extracted key $key|nok" "ERROR"
                            return_code=1
                    fi
            else
                    log "$log_text|delete extracted key $key|$http_return_code" "ERROR"
                    log "$log_text|delete extracted key $key|nok" "ERROR"
                    return_code=1
            fi
        done
    fi

    exit_on_error_or_proceed $return_code "$log_text"
}

function main(){

    check_rancher_url
    get_token
    check_user_name
    get_cluster_id
    write_kubeconfig
    cleanup_expired_keys
}

OPTS=$(getopt -o "$OPTS_CMD_LIST_SHORT" --long "$OPTS_CMD_LIST_LONG" -n "$progname" -- "$@")
if [ $? -eq  0 ] ; then
    eval set -- "$OPTS"
    while true; do
        case "$1" in
            -h | --help ) usage; exit 0 ;;
            -r | --rancher-url ) RANCHER_URL=$2; shift 2 ;;
            -c | --cluster-name ) CLUSTER_NAME=$2; shift 2 ;;
            -t | --token-file ) TOKEN_FILE=$2; shift 2 ;;
            --rancher-token-ttl ) RANCHER_TOKEN_TTL=$2; shift 2 ;;
            --login-token-ttl ) LOGIN_TOKEN_TTL=$2; shift 2 ;;
            -l | --ldap-file ) LDAP_FILE=$2; shift 2 ;;
            -k | --kubeconfig ) KUBECONFIG=$2; shift 2 ;;
            -u | --user-name ) USER=$2; shift 2 ;;
            -o | --overwrite ) OVERWRITE=true; shift ;;
            -s | --skip-cleanup ) CLEANUP_EXPIRED_KEYS=false; shift ;;
            -- ) shift; break ;;
            * ) break ;;

        esac
    done

    if  [ "$RANCHER_URL" == "" ] || [ "$RANCHER_URL" == "undefined" ] ||
        [ "$CLUSTER_NAME" == "" ] || [ "$CLUSTER_NAME" == "undefined" ] ||
        [ "$TOKEN_FILE" == "" ] || [ "$LDAP_FILE" == "" ] ||
        ( [ "$TOKEN_FILE" == "undefined" ] && [ "$RANCHER_TOKEN" == "undefined" ] &&
        [ "$LDAP_FILE" == "undefined" ] && [ "$LDAP_USER" == "undefined" ] && [ "$LDAP_PWD" == "undefined" ] ) ||
        [ "$USER_NAME" == "" ] ||
        ( [ "$OVERWRITE" != "false" ] && [ "$OVERWRITE" != "true" ] ); then

        if [ ${#SCRIPT_PARAMETERS[@]} -eq 0 ]; then
            echo "No arguments provided"
        fi

        cat << DEBUG_OUTPUT

     Parameter Summary:

     Rancher URL:                         $RANCHER_URL
     Cluster Name:                        $CLUSTER_NAME
     Token File:                          $TOKEN_FILE
     Rancher Token:                       $(if [ "$RANCHER_TOKEN" == "undefined" ]; then echo "undefined"; else echo "*********";fi )
     Ldap File:                           $TOKEN_FILE
     Ldap User:                           $LDAP_USER
     Ldap Password:                       $(if [ "$LDAP_PWD" == "undefined" ]; then echo "undefined"; else echo "*********";fi )
     Overwrite:                           $OVERWRITE
     Username:                            $USER_NAME
     KUBECONFIG:                          $KUBECONFIG

DEBUG_OUTPUT

        usage
        exit 1
    fi

    main
else
  echo "Error in command line arguments." >&2
  usage
fi
