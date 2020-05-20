#!/bin/bash
set -u

_main() {
    local fn=${FUNCNAME[0]}

    trap '_except $LINENO' ERR

    if [[ "${1:-NOP}" != NOP ]]; then
        local ns="$1"
    else
        _help; false
    fi

    if [[ "${2:-NOP}" != NOP ]]; then
        local release="$2"
    else
        _help; false
    fi

    if [[ "${3:-NOP}" != NOP ]]; then
        local job_name="$3"
    else
        _help; false
    fi

    printf '\033[1;31m%s\033[1;35m' "Get pods status:"
    printf -- '-%.0s' {1..115}
    printf '\033[0m\n'
    kubectl -n "$ns" get po -lrelease="$release" -o wide
    printf '\033[1;31m%s\033[1;35m' "Get events:"
    printf -- '-%.0s' {1..115}
    printf '\033[0m\n'
    kubectl -n "$ns" get events --field-selector involvedObject.kind=Pod,type=Warning --sort-by='.lastTimestamp'

    local -a Daemonsets=() Deployments=() Statefulsets=()

    mapfile -t Daemonsets < <( kubectl -n "$ns" get daemonset -lrelease="$release" --no-headers -o custom-columns=":metadata.name" )
    mapfile -t Deployments < <( kubectl -n "$ns" get deployment -lrelease="$release" --no-headers -o custom-columns=":metadata.name" )
    mapfile -t Statefulsets < <( kubectl -n "$ns" get statefulset -lrelease="$release" --no-headers -o custom-columns=":metadata.name" )

    for (( i = 0; i < ${#Daemonsets[@]}; i++ )); do
        __not_ready DaemonSet "${Daemonsets[i]}"
    done

    for (( i = 0; i < ${#Deployments[@]}; i++ )); do
        __not_ready Deployment "${Deployments[i]}"
    done

    for (( i = 0; i < ${#Statefulsets[@]}; i++ )); do
        __not_ready StatefulSet "${Statefulsets[i]}"
    done

    exit 0
}

__not_ready() {
    local not_ready=""
    local text="of first not-ready pod"

    not_ready=$(kubectl -n "$ns" get po -lrelease="$release" -o=go-template --template='{{range $i := .items}}{{range .status.containerStatuses}}{{if not .ready}}{{printf "%s\n" $i.metadata.name}}{{end}}{{end}}{{end}}' | grep -v "^$job_name" | head -n 1)

    if [[ -n "$not_ready" ]]; then

        printf '\033[1;31m%s\033[1;35m' "$1 ${2}: logs ${text}: "
        printf -- '-%.0s' {1..82}
        printf '\033[0m\n'
        __logs
    fi
}

__logs() {
    kubectl -n "$ns" logs "$not_ready" || :
}

_except() {
    local ret=$?
    local no=${1:-no_line}

    echo "error occured in function '$fn' near line ${no}, exit code ${ret}. Continuing..."
}

_help() {
    echo "Usage: $0 <metadata.namespace> <metadata.labels.release> <metadata.name>" >&2
}

_main "$@"

