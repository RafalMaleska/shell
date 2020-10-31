#compdef _function kgsecvalue kgsecv

local -a secrets

secrets=(
  $(
    kubectl get secrets -o=go-template='{{ with .metadata.name }}{{.}}{{ else }}{{range .items }}{{println .metadata.name}}{{end}}{{ end }}'
  )
)

_arguments "1: :( $( echo $secrets ))"
