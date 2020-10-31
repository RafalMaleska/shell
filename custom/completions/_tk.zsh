#compdef _function start_tmux_kube tmux_kube tk

local -a _context_list

_context_list=(
  $(
    kubectl config get-contexts --no-headers 2>/dev/null| sort  2>/dev/null | awk '{print $2}'
  )
)

_alternative "kube:sessions:( $( echo $_context_list ) )"
