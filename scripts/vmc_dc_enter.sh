#!/usr/bin/env bash
docker_user="${USER}"
script_name=$0

function do_help()
{
    filename=$(basename $script_name)
    printf "Usage ($filename) : Get into one particular container\n"
    printf "\t (-n or --name) name of the container\n"
    printf "\t (-r or --root) log in as root\n"
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

log_in_as_root=0

function parse_arguments() {
    while [ $# -gt 0 ]; do
        local opt="$1"
        shift
        case "${opt}" in
            -r | --root)
                log_in_as_root=1
                shift
                ;;

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
                error "Unknown option: ${opt}"
                exit 2
                ;;
        esac
    done # End while loop
}

parse_arguments "$@"

if [[ ! $container_name =~ ^$docker_user ]]; then
    error "Sorry! (Current User: $docker_user). Container ($container_name) is not your container. DO NOT get into other people's containers. Exit!" 0
fi

xhost +local:root 1>/dev/null 2>&1

if [ $log_in_as_root -eq 1 ]; then
    info "Log in as root"
    docker_user="0"
fi

docker exec \
    -u "${docker_user}" \
    -e HISTFILE=$HOME/.vmc_dc_bash_hist \
    -it "${container_name}" \
    /bin/bash

xhost -local:root 1>/dev/null 2>&1
