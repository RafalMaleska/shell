# requires exa
alias ls='exa --git --color=always --group-directories-first'
alias du='dust'
# to enable watch to use aliased commands
alias watch="watch "

# to add some tmux gimmics
alias kc='kubectx'
alias ta='tmux-attach '
alias tn='tmux-new '
alias ts='tmux-switch '
alias git-changelog="git tag -l --sort=-v:refname -n100 2> /dev/null | sed 's/^\([0-9]\+\.[0-9]\+\.[0-9]\+\)\s\+/\n\1\n    /g' 2> /dev/null | less "
alias changelog="git-changelog "
alias cl="git-changelog "

tmux-attach(){
    tmux -2 attach-session -d -t ${1:=$(whoami)}
}

tmux-new(){
    tmux -2 new-session -s  ${1:=$(whoami)}
}

tmux-switch(){
    local session_name="$1"
    if [[ -z "$session_name" ]]; then
	echo "Parameter 1 is missing, please specify tmux sesssion name you wish to switch to!"
	return 1
    fi
    tmux switch -t "${session_name}"
}
