#!/bin/zsh

: "${KUBE_CONFIG_FOLDER:=${HOME}/.kube}"

export KUBE_CONFIG_TEMP_FOLDER="$KUBE_CONFIG_FOLDER/temp"
export TMUX_WINDOW_FILE=$KUBE_CONFIG_TEMP_FOLDER/tmux_window_name

: "${RANCHER_CLUSTER_DOMAIN:=placeholder.com}"

RANCHER_CLUSTER_DEV_DEFAULT=(
    devops-dev-rancher01
    devops-dev-rancher02
    devops-dev-rancher03
)

RANCHER_CLUSTER_TEST_DEFAULT=(
    devops-test-rancher01
    devops-test-rancher02
    devops-test-rancher03
)

RANCHER_CLUSTER_PRD_DEFAULT=(
    devops-prd-rancher01
    devops-prd-rancher02
    devops-prd-rancher03
)

RANCHER_CLUSTER_DEFAULT=(
    $RANCHER_CLUSTER_DEV_DEFAULT
    $RANCHER_CLUSTER_TEST_DEFAULT
    $RANCHER_CLUSTER_PRD_DEFAULT
)

REACHABLE_RANCHER_CLUSTER=()

CONTEXT_FOLDER=$KUBE_CONFIG_FOLDER/contexts
CONTEXT_BASE_FILE_NAME=context
CONTEXT_BASE_FILE=$CONTEXT_FOLDER/$CONTEXT_BASE_FILE_NAME
CONTEXT_FILE="$CONTEXT_BASE_FILE"
KUBE_CONFIG_PATTERN='config_*'

GET_KUBECONFIG="link-to-get-kubeconfig-shell"
LOGIN_TOKEN_TTL_DEFAULT=12000
RANCHER_TOKEN_TTL_DEFAULT=0

: "${LDAP_USER:=undefined}"
: "${LDAP_PWD:=undefined}"
: "${LDAP_FILE:=undefined}"
: "${LOGIN_TOKEN_TTL:=undefined}"
: "${RANCHER_TOKEN_TTL:=undefined}"

: "${KUBE_CONFIG_PREFIX:=config_}"
: "${KUBE_CONFIG_KCU_MODIFIER:=kcu_}"
: "${KUBE_CONFIG_OVERWRITE:=true}"
: "${KUBE_CONFIG_AUTO_UPDATE:=true}"

function cleanup_kubeconfig_context () {
    echo "${CONTEXT_FILE//*\//}" | grep -q "_[0-9]*$" &> /dev/null
    if [ $? -eq 0 ]; then
        rm -f $CONTEXT_FILE
    fi
}

function cleanup_unused_context () {
    local expected_files found_files context_list
    found_files=( $(find $CONTEXT_FOLDER -name "${CONTEXT_BASE_FILE_NAME}_tmux_name*" -exec basename {} \; 2> /dev/null ) )

    context_list=( $(kubectl config get-contexts --no-headers | sort  2>/dev/null | awk '{print $2}') )
    expected_files=( $(printf "${CONTEXT_BASE_FILE_NAME}_tmux_name_%s\n" "${context_list[@]}" ) "context_tmux_name_scratchpad" )
    # delete the unexpected
    for file in  ${found_files:|expected_files}; do
        rm -f $CONTEXT_FOLDER/$file
    done
}

function get_reachable_rancher_cluster () {
    local return_value cluster_url reachable_count rancher_urls=("$@")

    echo -n "$(date)|Determine reachable rancher cluster|"

    REACHABLE_RANCHER_CLUSTER=()

    for cluster in "${rancher_urls[@]}"; do
        nc -w 3 -z ${cluster//*\//} 443 &> /dev/null
        if [ $? -eq 0 ]; then
            REACHABLE_RANCHER_CLUSTER+=( "$cluster" )
        fi
    done
    reachable_count=${#REACHABLE_RANCHER_CLUSTER[@]}
    if [ $reachable_count -gt 0 ]; then
        echo "ok, found $reachable_count reachable rancher cluster"
    else
        echo "nok, no url of the following list is reachable, please check your network connection and/or talk to your ops ;)"
        echo "\nChecked Cluster Urls:\n"
        printf "%s\n" "${rancher_urls[@]}"
        return 1
    fi
}

function update_kubeconfigs () {
    local rancher_urls rancher2_urls url_tokens given_rancher_urls permitted_cluster ldap_required rancher_message token ldap_file_string
    local login_token ttl_msg kubeconfig_path overwrite return_code return_value rancher_urls_count return_value_login return_code_all

    rancher_urls=()
    rancher_urls_count=0
    return_code_all=0
    given_rancher_urls="$1"
    ldap_required="false"

    echo "$(date)|Updating kubeconfig|..."

    echo -n "$(date)|Adding rancher cluster from default list|"
    rancher_urls+=( $(printf "https://%s.$RANCHER_CLUSTER_DOMAIN\n" "${RANCHER_CLUSTER_DEFAULT[@]}") )
    rancher_urls_count=${#rancher_urls[@]}
    echo "ok, $rancher_urls_count urls added"

    if [[ "$given_rancher_urls" != "" ]]; then
        echo -n "$(date)|Adding given cluster urls to cluster urls|"
        rancher_urls+=( $( echo "$given_rancher_urls" | tr "," "\n" ) )
        rancher_urls_count=${#rancher_urls[@]}
        echo "ok, $rancher_urls_count urls added"
    fi

    echo -n "$(date)|Extract cluster server urls from kubeconfigs|"
    rancher_urls+=( $( kubectl config view -o json  | jq -r '.clusters[].cluster.server' | sed -r 's#(^http[s]*://[^/]*).*#\1#g' | sort | uniq) )

    if [ ${#rancher_urls[@]} -eq $rancher_urls_count ]; then
        echo "nok, no urls found"
    else
        echo "ok, $(( ${#rancher_urls[@]} - $rancher_urls_count)) urls added"
        rancher_urls_count=${#rancher_urls[@]}
    fi

    # delete duplications
    echo -n "$(date)|Delete duplictions|"
    rancher_urls=( $(printf "%s\n" "${rancher_urls[@]}" | sort | uniq ) )
    if [[ ${#rancher_urls[@]} -eq $rancher_urls_count ]]; then
        echo "skipped, no duplications found"
    else
        echo "ok, $(($rancher_urls_count - ${#rancher_urls[@]} )) url(s) deleted"
    fi

    # reachable cluster urls were stored in global array REACHABLE_RANCHER_CLUSTER
    get_reachable_rancher_cluster "${rancher_urls[@]}"

    echo "$(date)|Update local kubeconfigs for all permitted k8s-cluster by using rancher2 cluster urls"
    for rancher_cluster in "${REACHABLE_RANCHER_CLUSTER[@]}"; do
        echo "$(date)|Proceeding $rancher_cluster|..."
        return_value=$(curl -s "$rancher_cluster" 2>&1)
        if [[ $? -eq 0 ]]; then
            api_information=$( echo "$return_value" | jq -r '. | select(.data != null) | .data[] | .apiVersion.group + "," + .apiVersion.version' )
            if [[ $? -eq 0 ]]; then
                if [[ "$api_information" == "" ]]; then
                    echo "$(date)|Proceeding $rancher_cluster|url is no rancher2 cluster, skipping"
                    echo "$(date)|Proceeding $rancher_cluster|ok"
                    continue
                fi
            else
                echo "$(date)|Proceeding $rancher_cluster|jq error while checking url for beeing rancher2 at response, skipping ($return_value)"
                ((return_code_all+=1))
                continue
            fi
        else
            echo "$(date)|Proceeding $rancher_cluster|url could not be checked, skipping"
            ((return_code_all+=1))
            continue
        fi

        permitted_cluster=()

        echo -n "$(date)|Proceeding $rancher_cluster|extract rancher token from local kubeconfig|"
        token=$( kubectl config view -o json | jq -r '(.clusters[] | select( .cluster.server | contains("'$rancher_cluster'") ) .name ) as $contextName |
                                                      (.contexts[] | select( .name == $contextName ) | .context.user  )         as $userName    |
                                                      .users[] | select( .name == $userName ) | .user.token' | sort | uniq 2>&1 )

        if [[ $? -eq 0 ]] && [[ "$token" != "" ]]; then
            echo "ok"
            echo -n "$(date)|Proceeding $rancher_cluster|get permitted k8s-cluster|"
            return_value=$(curl -s \
                                -H 'content-type: application/json' \
                                -H "Authorization: Bearer $token" \
                                "$rancher_cluster/v3/clusters" 2>&1 )

            return_code=$?
            if [[ $return_code -eq 0 ]]; then
                permitted_cluster=( $(echo "$return_value" | jq -r 'select(.data != null) | .data[].name' | grep -v "local" ) )
                if [[ ${#permitted_cluster[@]} -gt 0 ]]; then
                    echo "ok"
                else
                    rancher_message="$(echo $return_value | jq -r 'select(.message != null) | .message' 2>/dev/null)"
                    if [[ "$rancher_message" == "must authenticate" ]]; then
                        echo "nok, token is not valid, ldap authentification is needed"
                        ldap_required="true"
                    else
                        echo "nok, no permitted cluster found, skipping rancher cluster"
                        echo "$(date)|Proceeding $rancher_cluster|ok"
                        continue
                    fi
                fi
            else
                echo "nok, error on request, response $return_value"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                ((return_code_all+=1))
                continue
            fi
        else
            echo "nok, no rancher token found, ldap authentication is needed!"
            ldap_required="true"
        fi


        if [[ "$ldap_required" == "true" ]]; then
            echo "$(date)|Proceeding $rancher_cluster|get ldap credentials|..."
            if [[ "$LDAP_USER" != "undefined" ]] && [[ "$LDAP_USER" != "" ]] && [[ "$LDAP_PWD" != "undefined" ]] && [[ "$LDAP_PWD" != "" ]]; then
                echo "$(date)|Proceeding $rancher_cluster|get ldap credentials|using given environment variables LDAP_USER and LDAP_PWD for ldap authentification"
            elif [[ "$LDAP_FILE" != "undefined" ]]; then
                echo "$(date)|Proceeding $rancher_cluster|get ldap credentials|using given LDAP_FILE $LDAP_FILE for ldap authentification"
                LDAP_FILE=$(readlink -f $LDAP_FILE)
                if [[ -f "$LDAP_FILE" ]]; then
                    ldap_file_string=$(cat $LDAP_FILE)
                    if [[ "$LDAP_FILE" != "" ]]; then
                        export LDAP_USER=${ldap_file_string%%:*}
                        export LDAP_PWD=${ldap_file_string#*:}
                    else
                        echo "nok, $LDAP_FILE is empty"
                        ((return_code_all+=1))
                        continue
                    fi
                else
                    echo "nok, $LDAP_FILE is missing"
                    ((return_code_all+=1))
                fi
            else
                echo "\nPlease enter your LDAP-Credentials:\n"
                echo -n "User: "
                read LDAP_USER
                echo -n "Password: "
                read -s LDAP_PWD
                echo "\n"
            fi

            if [[ "$LDAP_USER" == "" ]] || [[ "$LDAP_PWD" == "" ]] || [[ "$LDAP_PWD" == "undefined" ]] || [[ "$LDAP_USER" == "undefined" ]]; then
                echo "$(date)|Proceeding $rancher_cluster|get ldap credentials|nok, LDAP_USER and LDAP_PWD must not be an empty string, skipping"
                ((return_code_all+=1))
                continue
            fi

            echo "$(date)|Proceeding $rancher_cluster|get ldap credentials|ok"
            echo -n "$(date)|Proceeding $rancher_cluster|get token with ldap credentials|"
            if [[ "$LOGIN_TOKEN_TTL" == "undefined" ]] || [[ -z "$LOGIN_TOKEN_TTL" ]] || [[ "$LOGIN_TOKEN_TTL" == "" ]]; then
                LOGIN_TOKEN_TTL=$LOGIN_TOKEN_TTL_DEFAULT
            fi

            return_value_login=$(curl -s -X POST \
                                        -H 'Accept: application/json' \
                                        -H 'Content-Type: application/json' \
                                        -d '{
                                              "description": "get-kubeconfig login-token",
                                              "labels": {
                                                "ui-session": "true"
                                              },
                                              "password": "'$LDAP_PWD'",
                                              "responseType":"json",
                                              "ttl":'$LOGIN_TOKEN_TTL',
                                              "username":"'$LDAP_USER'"
                                        }' \
                                        "$rancher_cluster/v3-public/openLdapProviders/openldap?action=login" 2>&1 )

            if [[ $? -ne 0 ]]; then
                echo "nok, error on request, response $return_value_login"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                ((return_code_all+=1))
                continue
            fi

            login_token=$(echo "$return_value_login" | jq -r ' select(.token != null) | .token ' 2>&1)

            if [[ $? -ne 0 ]]; then
                echo "nok, error on extracting token from response $return_value_login"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                ((return_code_all+=1))
                continue
            fi

            if [[ "$login_token" == "" ]]; then
                echo "nok, login token is empty, response $return_value_login"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                echo "$(date)|Updating kubeconfig|nok"
                unset LDAP_USER
                unset LDAP_PWD
                unset LOGIN_TOKEN_TTL
                unset RANCHER_TOKEN_TTL
                unset RANCHER_TOKEN
                return 1
            fi

            if [[ "$RANCHER_TOKEN_TTL" == "undefined" ]] || [[ -z "$RANCHER_TOKEN_TTL" ]] || [[ "$RANCHER_TOKEN_TTL" == "" ]]; then
                RANCHER_TOKEN_TTL=$RANCHER_TOKEN_TTL_DEFAULT
            fi
            ttl_msg=" "
            [[ $RANCHER_TOKEN_TTL -gt 0 ]] && ttl_msg=" temporary "
            return_value=$(curl -s \
                                -H 'content-type: application/json' \
                                -H "Authorization: Bearer $login_token" \
                                -d '{
                                      "type": "token",
                                      "ttl": '$RANCHER_TOKEN_TTL',
                                      "description": "get-kubeconfig'"$ttl_msg"'token"
                                }' \
                                "$rancher_cluster/v3/token" 2>&1 )
            if [[ $? -ne 0 ]]; then
                echo "nok, error on request, response $return_value"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                ((return_code_all+=1))
                continue
            fi

            token=$(echo "$return_value" | jq -r ' select(.token != null) | .token ' 2>&1 )
            if [ "$token" != "" ]; then
                echo "ok"
            else
                echo "nok, rancher token is empty"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                ((return_code_all+=1))
                continue
            fi

            echo -n "$(date)|Proceeding $rancher_cluster|get permitted k8s-cluster|"
            return_value=$(curl -s \
                                -H 'content-type: application/json' \
                                -H "Authorization: Bearer $token" \
                                "$rancher_cluster/v3/clusters" 2>&1 )

            return_code=$?
            if [[ $return_code -ne 0 ]]; then
                echo "nok, error on request, response $return_value"
                echo "$(date)|Proceeding $rancher_cluster|nok"
                ((return_code_all+=1))
                continue
            fi

            permitted_cluster=( $(echo "$return_value" | jq -r 'select(.data != null) | .data[].name' | grep -v "local" 2>&1 ) )
            if [[ ${#permitted_cluster[@]} -gt 0 ]]; then
                echo "ok"
            else
                rancher_message="$(echo $return_value | jq -r 'select(.message != null) | .message' 2>/dev/null)"
                if [[ "$rancher_message" == "must authenticate" ]]; then
                    echo "nok, token is not valid ($token)"
                    ((return_code_all+=1))
                else
                    echo "nok, no permitted cluster found, skipping rancher cluster"
                    echo "$(date)|Proceeding $rancher_cluster|nok"
                    ((return_code_all+=1))
                    continue
                fi
            fi
        fi

        if [[ "$KUBE_CONFIG_OVERWRITE" == "true" ]]; then
            overwrite="-o"
        else
            overwrite=""
        fi

        for user_cluster in "${permitted_cluster[@]}"; do
            echo -n "$(date)|Proceeding $rancher_cluster|start get-kubeconfig for $user_cluster|"
            export RANCHER_TOKEN=$token
            kubeconfig_path="$KUBE_CONFIG_FOLDER/${KUBE_CONFIG_PREFIX}${KUBE_CONFIG_KCU_MODIFIER}${user_cluster}"
            return_value=$(eval $GET_KUBECONFIG  --rancher-url "$rancher_cluster" \
                                                 --cluster-name "$user_cluster" \
                                                 --kubeconfig $kubeconfig_path \
                                                 $overwrite 2>&1 )

            if [[ $? -eq 0 ]]; then
                echo "ok"
            else
                echo "nok"
                ((return_code_all+=1))
                echo "$return_value"
            fi
        done
        echo "$(date)|Proceeding $rancher_cluster|ok"
    done

    unset LDAP_USER
    unset LDAP_PWD
    unset LOGIN_TOKEN_TTL
    unset RANCHER_TOKEN_TTL
    unset RANCHER_TOKEN

    if [[ $return_code_all -eq 0 ]]; then
        echo "$(date)|Updating kubeconfig|ok"
    else
        echo "$(date)|Updating kubeconfig|mok, $return_code_all errors occurred!"
        return 1
    fi

    export_kubeconfig
}

function export_kubeconfig () {
    local base_config=1 kube_configs kube_config_string kube_configs_sorted=()

    kube_configs=( $( find $KUBE_CONFIG_FOLDER -name "$KUBE_CONFIG_PATTERN" ! -name "*.bak" 2> /dev/null ) )

    kube_configs_sorted+=( $( printf "%s\n" "${kube_configs[@]}" | grep -v -e "-test-\|-tst-\|-prd-\|-prod-" | sort -n ) )
    kube_configs_sorted+=( $( printf "%s\n" "${kube_configs[@]}" | grep -e "-test-\|-tst-" | sort -n  ) )
    kube_configs_sorted+=( $( printf "%s\n" "${kube_configs[@]}" | grep -e "-prod-\|-prd-" | sort -n ) )

    if [[ ${#kube_configs_sorted[@]} -gt 0 ]]; then
        kube_config_string=$(IFS=':'; echo "$kube_configs_sorted" )
        export KUBECONFIG="$CONTEXT_FILE:$kube_config_string"
    else
        if [[ "$KUBE_CONFIG_AUTO_UPDATE" != "false" ]]; then
            echo "$(date)|no kubeconfigs found in path $KUBE_CONFIG_FOLDER with pattern $KUBE_CONFIG_PATTERN, starting auto update"
            echo "$(date)|if you want to disable auto update, please set KUBE_CONFIG_AUTO_UPDATE=false in your ~/.zshrc"
            update_kubeconfigs
        fi
    fi
}

function prepare_temp () {
    mkdir -p $KUBE_CONFIG_TEMP_FOLDER
}


function prepare_context () {

    mkdir -p $CONTEXT_FOLDER

    if [ ! -f $CONTEXT_BASE_FILE ]; then
        cat <<EOM > $CONTEXT_BASE_FILE
apiVersion: v1
clusters: []
contexts: []
current-context:
kind: Config
preferences: {}
users: []
EOM
    fi

}

function deterine_context_file_name () {
    local my_shell_pid=$$
    local tmux_window_file="$TMUX_WINDOW_FILE"

    if [ "$TERM" = "screen-256color" -a -n "$TMUX" ]; then
        if [ -f "$tmux_window_file" ]; then
            echo "read $tmux_window_file"
            WINDOW_NAME=$(cat $tmux_window_file)
        else
            WINDOW_NAME=$(tmux display-message -p '#W')
        fi
        WINDOW_INDEX=$(tmux display-message -p '#I')
        SESSION_NAME=$(tmux display-message -p '#S')
        PANE_INDEX=$(tmux display -pt "${TMUX_PANE:?}" '#{pane_index}')
        if (echo "$WINDOW_NAME" | grep -Eq '^(tmux|.*/.*|zsh)$' ); then
            CONTEXT_FILE="${CONTEXT_BASE_FILE}_tmux_${SESSION_NAME}_index_$WINDOW_INDEX"
        else
            CONTEXT_FILE="${CONTEXT_BASE_FILE}_tmux_${SESSION_NAME}_name_$WINDOW_NAME"
        fi
    else
        CONTEXT_FILE="${CONTEXT_BASE_FILE}_zsh_${my_shell_pid}"
    fi

    if [ "$CONTEXT_BASE_FILE" != "$CONTEXT_FILE" ]; then
        if [ ! -f "$CONTEXT_FILE" ]; then
            cp -f $CONTEXT_BASE_FILE $CONTEXT_FILE
        fi
    fi
}

function start_tmux_kube () {

    local search_patterns context_list window_list new_context_list sleep_time_short sleep_time_middle sleep_time_long

    search_patterns="$*"

    new_context_list=()

    export_kubeconfig

    sleep_time_short="0.2"
    sleep_time_middle="0.5"
    sleep_time_long="1"
    platform=$(uname | tr '[:upper:]' '[:lower:]' )

    if [[ "$platform" == "darwin" ]]; then
	sleep_time_short="0.1"
	sleep_time_middle="0.2"
	sleep_time_long="0.3"
    fi

    context_list=(
        $(
            kubectl config get-contexts --no-headers | sort  2>/dev/null | awk '{print $2}'
        )
    )

    for filter in $*; do
        new_context_list+=(
            $(
                printf "%s\n" "${context_list[@]}" | grep -e "$filter"
            )
        )
    done

    if [ "${#new_context_list}" -eq 0 ]; then
	echo "no context found for pattern(s) $(printf "%s" "${search_patterns[@]}" )"
	return 1
    fi
    context_list=("${new_context_list[@]}")

    sn="$(whoami)-kube"

    if [ -z "$TMUX" ]; then
        echo "start tmux server"
        tmux start-server
    else
        echo "tmux-kube must not be started within tmux, please exit tmux first!"
        return 0
    fi

    tmux list-sessions 2> /dev/null | grep -q "$sn"
    if [ $? -ne 0 ]; then
        echo "create new session with name $sn"
        tmux new-session -s "$sn" -n scratchpad -c $(pwd) -d
        sleep $sleep_time_middle
        window_list=""
    else
        window_list=$(tmux list-windows -t "$sn" -F "#W")
    fi

    counter=1
    for context in "${context_list[@]}"; do
        tmux select-window -t "$sn:1"
        echo "$window_list" | grep -q "^$context$" &> /dev/null
        if [ $? -ne 0 ]; then
	    tmux_temp_context_file=$KUBE_CONFIG_TEMP_FOLDER/temp_$context
            echo "create new window for context: $context"
            tmux new-window -a -n "$context"
            sleep $sleep_time_short
            tmux send-keys -t "1" "kubectl config use-context $(tmux display-message -p '#W')" C-m
            tmux send-keys -t "1" C-l
            sleep $sleep_time_short
            tmux splitw -h -p 50
            tmux selectp -t 2
            tmux send-keys -t "2" "watch kgp -n deployment \"| grep -v Completed\""
            tmux splitw -v -p 66
            tmux selectp -t 3
            tmux splitw -v -p 50
            tmux selectp -t 1
            tmux send-keys -t "4" "touch $tmux_temp_context_file;clear" C-m
            while [ ! -f $tmux_temp_context_file ]; do
              sleep $sleep_time_middle
            done
	        sleep $sleep_time_middle
	        rm -rf $tmux_temp_context_file
            tmux send-keys -t "1" "source ~/.zshrc" C-m
	    sleep $sleep_time_short
            tmux send-keys -t "1" C-l
            tmux send-keys -t "1" C-l
        else
            echo "window for context: $context already exists, skipping"
        fi
        sleep $sleep_time_long
        counter=$(($counter+1))
    done

    tmux -2 attach-session -t "$sn"
}

function () {
    prepare_temp
    prepare_context
    deterine_context_file_name
    export_kubeconfig
    cleanup_unused_context
}

alias tmux-kube="start_tmux_kube"
alias tk="start_tmux_kube "
alias tmux-kube-exit="tmux kill-session"
alias tmux-exit="tmux kill-session"
alias te="tmux kill-session"
alias kcu="update_kubeconfigs"
alias kce="export_kubeconfig"
alias get-kubeconfig="$GET_KUBECONFIG"
