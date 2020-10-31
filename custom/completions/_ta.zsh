#compdef _function tmux-attach ta

local -a _tmux_sessions

_tmux_sessions=(
	$(tmux ls 2> /dev/null | cut -d ":" -f 1 )
)

_arguments '1: :( $( echo $_tmux_sessions ) )'
