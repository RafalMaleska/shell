if (( $+commands[kubectl] )); then
    __KUBECTL_COMPLETION_FILE="${ZSH_CACHE_DIR}/kubectl_completion"

    if [[ ! -f $__KUBECTL_COMPLETION_FILE ]]; then
        kubectl completion zsh >! $__KUBECTL_COMPLETION_FILE
    fi

    [[ -f $__KUBECTL_COMPLETION_FILE ]] && source $__KUBECTL_COMPLETION_FILE

    unset __KUBECTL_COMPLETION_FILE
fi

# This command is used a LOT both below and in daily life
alias k=kubectl

# Execute a kubectl command against all namespaces
alias kca='f(){ kubectl "$@" --all-namespaces;  unset -f f; }; f'

# Apply a YML file
alias kaf='kubectl apply -f'
alias kaf-='kaf -'

# Drop into an interactive terminal on a container
alias keti='kubectl exec -ti'

# Manage configuration quickly to switch contexts between local, dev ad staging.

alias kc='kubectx'
alias kn='kubens'
alias kcn='kubens'
alias kcgc='kubectl config get-contexts'
alias kcuc='kubectx'
alias kcsc='kubectl config set-context'
alias kcdc='kubectl config delete-context'
alias kccc='kubectl config current-context'

# General aliases
alias kg='k get'
alias ke='k edit'
alias kd='k describe'
alias ka='k annotate'
alias kdel='kubectl delete'
alias kdelf='kubectl delete -f'
alias kdelf-='kdelf -'

# Pod management.
alias kgp='kg pods'
alias kgpw='kgp --watch'
alias kgpwide='kgp -o wide'
alias kgpyaml='kgp -o yaml'
alias kgpjson='kgp -o json'
alias kep='ke pods'
alias kdp='kd pods'
alias kap='ka pod --overwrite'
alias kdelp='kdel pods'
alias murder="kdelp --grace-periode=0 --force "

# get pod by label: kgpl "app=myapp" -n myns
alias kgpl='kgp -l'
alias kgplyaml='kgpyaml -l'
alias kgpljson='kgpjson -l'

# Service management.
alias kgs='kg svc'
alias kgsw='kgs --watch'
alias kgswide='kgs -o wide'
alias kgsyaml='kgs -o yaml'
alias kgsjson='kgs -o json'
alias kes='ke svc'
alias kds='kd svc'
alias kas='ka svc --overwrite'
alias kdels='kdel svc'

# Ingress management
alias kgi='kg ingress'
alias kgiyaml='kgi -o yaml'
alias kgijson='kgi -o json'
alias kei='ke ingress'
alias kdi='kd ingress'
alias kai='ka ingress --overwrite'
alias kdeli='kdel ingress'

# Namespace management
alias kgns='kg namespaces'
alias kcns='k create namespace'
alias kgnsyaml='kgns -o yaml'
alias kgnsjson='kgns -o json'
alias kgns='kg namespaces'
alias kens='ke namespace'
alias kdns='kd namespace'
alias kans='ka namespace --overwrite'
alias kdelns='kdel namespace'
# alias kcn='kubectl config set-context $(kubectl config current-context) --namespace'

# ConfigMap management
alias kgcm='kg configmaps'
alias kgcmyaml='kgcm -o yaml'
alias kgcmjson='kgcm -o json'
alias kecm='ke configmap'
alias kdcm='kd configmap'
alias kacm='ka configmap --overwrite'
alias kdelcm='kdel configmap'

# Secret management
alias kgsec='kg secret'
alias kgsecyaml='kgsec -o yaml'
alias kgsecjson='kgsec -o json'
kgsecvalue(){
    kgsec $1 -o json | jq '
    	if .data != null then
	    .
	else
            .items[]
	end |
        .metadata.name as $name |
	.metadata.namespace as $namespace |
	.data as $date |
	[{ name: $name, namespace: $namespace, data: ( $date | to_entries | map(.value=(.value | @base64d))) | from_entries}]
    ' | jq -s add | jq '{ secrets: . }' | yq r - -P
}
alias kgsecv="kgsecvalue "
alias kdsec='kd secret'
alias kasec='ka secret --overwrite'
alias kdelsec='kdel secret'

# Service account management
alias kgsa='kg serviceaccount'
alias kcsa='k create serviceaccount'
alias kgsaw='kgsa --watch'
alias kgsawide='kgsa -o wide'
alias kgsayaml='kgsa -o yaml'
alias kgsajson='kgsa -o json'
alias kesa='ke serviceaccount'
alias kdsa='kd serviceaccount'
alias kasa='ka serviceaccount --overwrite'
alias kdelsa='kdel serviceaccount'

# Job management
alias kgj='kg job'
alias kgjyaml='kgj -o yaml'
alias kgjjson='kgj -o json'
alias kej='ke job'
alias kdj='kd job'
alias kaj='ka job --overwrite'
alias kdelj='kdel job'

# Deployment management.
alias kgd='kg deployment'
alias kgdw='kgd --watch'
alias kgdwide='kgd -o wide'
alias kgdyaml='kgd -o yaml'
alias kgdjson='kgd -o json'
alias ked='ke deployment'
alias kdd='kd deployment'
alias kad='ka deployment --overwrite'
alias kdeld='kdel deployment'
alias ksd='k scale deployment'
alias krsd='k rollout status deployment'
kres(){
    kubectl set env $@ REFRESHED_AT=$(date +%Y%m%d%H%M%S)
}

# Statefulset management
alias kgsts='kg statefulset'
alias kgstsw='kgsts --watch'
alias kgstswide='kgsts -o wide'
alias kgstsyaml='kgsts -o yaml'
alias kgstsjson='kgsts -o json'
alias kests='ke statefulset'
alias kdsts='kd statefulset'
alias kasts='ka statefulset --overwrite'
alias kdelsts='kdel statefulset'
alias kssts='k scale statefulset'
alias krssts='k rollout status statefulset'

# Rollout management.
alias kgrs='kg rs'
alias krh='k rollout history'
alias kru='k rollout undo'

# Port forwarding
alias kpf="k port-forward"

# Tools for accessing all information
alias kga='kg all'
alias kgaa='kga --all-namespaces'

# Logs
alias kl='k logs'
alias klf='k logs -f'
alias klp='k logs -p'

# File copy
alias kcp='k cp'

# Node Management
alias kgno='kg nodes'
alias kgnowide='kgno -o wide'
alias kgnoyaml='kgno -o yaml'
alias kgnojson='kgno -o json'
alias keno='ke node'
alias kdno='kd node'
alias kano='ka node --overwrite'
alias kdelno='kdel node'

# Role and Rolebinding Management
alias kgr='kg roles'
alias kgryaml='kgr -o yaml'
alias kgrjson='kgr -o json'
alias ker='ke role'
alias kdr='kd role'
alias kar='ka role --overwrite'
alias kdelr='kdel role'
alias kgrb='kg rolebindings'
alias kgrbyaml='kgrb -o yaml'
alias kgrbjson='kgrb -o json'
alias kerb='ke rolebinding'
alias kdrb='kd rolebinding'
alias karb='ka rolebinding --overwrite'
alias kdelrb='kdel rolebinding'


# Clusterrole and Clusterrolebinding Management
alias kgcr='kg clusterroles'
alias kgcryaml='kgcr -o yaml'
alias kgcrjson='kgcr -o json'
alias kecr='ke clusterrole'
alias kdcr='kd clusterrole'
alias kacr='ka clusterrole --overwrite'
alias kdelcr='kdel clusterrole'
alias kgcrb='kg clusterrolebindings'
alias kgcrbyaml='kgcrb -o yaml'
alias kgcrbjson='kgcrb -o json'
alias kecrb='ke clusterrolebinding'
alias kdcrb='kd clusterrolebinding'
alias kacrb='ka clusterrolebinding --overwrite'
alias kdelcrb='kdel clusterrolebinding'

# kafka topics & references
alias kgkt='kg kt'
alias kgktyaml='kgkt -o yaml'
alias kgktjson='kgkt -o json'
alias kdkt='kd kt'
alias kekt='ke kt'
alias kakt='ka kt --overwrite'
alias kdelkt='kdel kt'
alias kgktr='kg ktr'
alias kgktryaml='kgktr -o yaml'
alias kgktrjson='kgktr -o json'
alias kdktr='kd ktr'
alias kektr='ke ktr'
alias kaktr='ka ktr --overwrite'
alias kdelktr='kdel ktr'

check_tool_name(){
    local tool_name=$1 return_value return_code
    if [[ -z "$tool_name" ]]; then
        echo "wrong invocation of check_tool_name, exit!"
        return 1
    fi

    return_value=$(brew info $tool_name)
    return_code=$?
    if [[ $return_code -ne 0 ]]; then
        echo "error on determining tool info for $tool_name, possibly $tool_name is not available in brew"
        return $return_code
    fi

    echo "$return_value" | grep -qi "not installed"
    if [[ $? -eq 0 ]]; then
        cat << EOM

$tool_name is not yet installed!

please use:

    export HOMEBREW_NO_INSTALL_CLEANUP=1
    brew install $tool_name

to install the latest version.

EOM
    return 1
    fi

    return 0
}

switch-version(){
    local tool_name tool_version tool_name_mapping pattern

    tool_name=$1
    tool_version=$2

    if [[ "$(uname | tr "[:upper:]" "[:lower:]" )" != "darwin" ]]; then
        echo "switch-version is not support on non darwin devices yet, sry"
        return 1
    fi

    if [[ -z "$tool_name" ]]; then
        echo "missing tool_name as first parameter"
        return 1
    fi

    tool_name_mapping=(
        "kubectl|kubernetes-cli"
    )

    pattern="${tool_name}\|*"

    if (($tool_name_mapping[(I)$pattern])); then
        tool_name=$(
            printf "%s\n" "${tool_name_mapping[@]}" | \
            grep -e "^$tool_name|" | \
            sed 's/.*|//'
        )
    fi

    ! check_tool_name "$tool_name" && return $?

    if [ -z $tool_version ]; then
        brew switch $tool_name 0 2>&1 | tail -n1
        return 0
    fi
    brew switch $tool_name $tool_version
}

update-versions(){
    local tools_to_upgrade tool_name tool_name_mapping pattern

    if [[ "$(uname | tr "[:upper:]" "[:lower:]" )" != "darwin" ]]; then
        echo "switch-version is not support on non darwin devices yet, sry"
        return 1
    fi

    tools_to_upgrade=(
        "helm"
        "helm@2"
        "kubectl"
        "helmfile"
    )

    tool_name_mapping=(
        "kubectl|kubernetes-cli"
    )

    pattern="${tool_name}\|*"

    brew update &> /dev/null

    export HOMEBREW_NO_INSTALL_CLEANUP=1

    for tool_name in ${tools_to_upgrade[@]}; do
        if (($tool_name_mapping[(I)$pattern])); then
            tool_name=$(
                printf "%s\n" "${tool_name_mapping[@]}" | \
                grep -e "^$tool_name|" | \
                sed 's/.*|//'
            )
        fi
        brew upgrade $tool_name
        if [[ $? -ne 0 ]]; then
            echo "Failed to upgrade tool $tool_name"
            return 1
        fi
    done

    export HOMEBREW_NO_INSTALL_CLEANUP=0
}

alias sv='switch-version '
alias uv='update-versions '

