#!/usr/bin/env bash
docker_user="${USER}"
script_name=$0

function do_help()
{
    filename=$(basename $script_name)
    printf "Usage ($filename) : Remove one particular container\n"
    printf "\t (-n) name of the container\n"
    printf "\t (-h or -help) to show help message\n"
}

function error()
{
    local _msg=$1
    local _do_help=$2
    echo -e "-E- $_msg"
    if [ $_do_help -eq 1 ]; then
        do_help
    fi 
    exit 1
}

function info()
{
    local _msg=$1
    echo "-I- $_msg"
    return 0
}

function _optarg_check_for_opt() {
    local opt="$1"
    local optarg="$2"

    if [[ -z "${optarg}" || "${optarg}" =~ ^-.* ]]; then
        error "Missing argument for ${opt}. Exiting..." 1
        exit 2
    fi
}

function parse_arguments() {
    while [ $# -gt 0 ]; do
        local opt="$1"
        shift
        case "${opt}" in
            -h | --help)
                do_help
                exit 0
                ;;

            -n | --name)
                container_name="$1"
                shift
                _optarg_check_for_opt "${opt}" "${container_name}"
                ;;
            *)
                error "Unknown option: ${opt}" 1
                exit 2
                ;;
        esac
    done # End while loop
}

parse_arguments "$@"

if [[ ! $container_name =~ ^$docker_user ]]; then
    error "Sorry! (Current User: $docker_user). Container ($container_name) is not your container. DO NOT remove other people's containers. Exit!" 0
fi

info "Now stop container ${container_name} ..."
if docker stop "${container_name}" >/dev/null; then
    docker rm "${container_name}" >/dev/null
    info "Done."
else
    warning "Failed."
fi
