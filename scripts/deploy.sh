#!/usr/bin/env bash

set -u

trap "exit 1" TERM
export TOP_PID=$$

: "${APPNAME:=deploy}"
: "${CIRCLE_FULL_ENDPOINT:=https://circleci.com/api/v1.1/project/github/$GITHUB_USER/$GITHUB_REPO}"
: "${CIRCLE_TAG:=}"

main() {
    need_cmd curl
    need_cmd jq

    if [ -z "$CIRCLE_TAG" ]; then
        say "Deploying only when CIRCLE_TAG is defined"
        exit 0
    fi

    # Get the list with CircleCI build numbers for the current tagged release
    local _builds=$(ensure circle "$CIRCLE_FULL_ENDPOINT")
    local _filter='.[] | select(.vcs_tag == "'$CIRCLE_TAG'" and .workflows.job_name != "deploy") | .build_num'
    local _build_nums=$(ensure jq "$_filter" <<< $_builds)

    IFS=$'\n'
    for build_num in $_build_nums; do
        say $build_num
    done
}

circle() {
    ensure curl "${1}?circle-token=$CIRCLE_TOKEN" \
        -s --retry 3 \
        -H "Accept: application/json"
}

say() {
    printf '\33[1m%s:\33[0m %s\n' "$APPNAME" "$1"
}

err() {
    printf '\33[1;31m%s:\33[0m %s\n' "$APPNAME" "$1" >&2
    kill -s TERM $TOP_PID
}

need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1; then
        err "need '$1' (command not found)"
    fi
}

ensure() {
    "$@"
    if [ $? != 0 ]; then
        err "command failed: $*";
    fi
}

main "$@" || exit 1
