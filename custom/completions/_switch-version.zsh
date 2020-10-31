#compdef _function switch-version sv

local -a commands

commands=(
    'kubectl:controls the Kubernetes cluster manager'
    'helm:The Kubernetes package manager'
    'helm@2:The Kubernetes package manager (old version 2.*)'
    'helmfile:Deploy Kubernetes Helm Charts'
    'minikube:Minikube is a CLI tool that provisions and manages single-node Kubernetes clusters optimized for development workflows.'
)

_arguments \
  "1: :{_describe 'command' commands}" \
  '*::arg:->args' \
  && ret=0

case $state in
    (args)
        _argument_values=$(brew switch ${words[1]} 0 2>&1 | tail -n1 | cut -d':' -f2 | sed 's/,//g' )
        _arguments '1: :( $( echo ${_argument_values} ) )'
        ;;
esac
