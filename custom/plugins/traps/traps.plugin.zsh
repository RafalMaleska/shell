
# function for cleanup zsh-suite on shell exit
function cleanup () {
    cleanup_kubeconfig_context
}

# definde traps
trap cleanup EXIT
