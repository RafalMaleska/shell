#compdef _function tmux-switch ts

local -a _tmux_session _tmux_sessions

_tmux_session=$(tmux display-message -p '#S' 2> /dev/null)

_tmux_sessions=(
	$(tmux ls 2> /dev/null | cut -d ":" -f 1 | grep -v "^$_tmux_session$" )
)

_arguments '1: :( $( echo $_tmux_sessions ) )'
