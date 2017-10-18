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
    need_cmd mkdir

    if [ -z "$CIRCLE_TAG" ]; then
        say "Deploying only when CIRCLE_TAG is defined"
        exit 0
    fi
    
    # Get the list with CircleCI build numbers for the current tagged release
    local _builds=$(ensure circle "$CIRCLE_FULL_ENDPOINT")
    local _filter='.[] | select(.vcs_tag == "'$CIRCLE_TAG'" and .workflows.job_name != "deploy") | .build_num'
    local _build_nums=$(ensure jq "$_filter" <<< $_builds)

    if [ -z "$_build_nums" ]; then
        err "No builds for tagged release $CIRCLE_TAG"
    fi

    ensure mkdir -p /tmp/artifacts

    IFS=$'\n'
    for build_num in $_build_nums; do
        say "Downloading artifacts for #${build_num}..."

        local _artifacts_json=$(ensure circle "$CIRCLE_FULL_ENDPOINT/$build_num/artifacts")
        local _artifacts=$(ensure jq -r '.[] | .url' <<< $_artifacts_json)
        for artifact in $_artifacts; do
            say $artifact
            (cd /tmp/artifacts; ensure curl -sSOL --retry 3 $artifact)
        done
    done
}

circle() {
    ensure curl "${1}?circle-token=$CIRCLE_TOKEN" \
        -sS --retry 3 \
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
