#!/usr/bin/env bash
docker_user="${USER}"
script_name=$0

function do_help()
{
    printf "Usage ($script_name) : Get into one particular container\n"
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

if [ "$1" != "-h" ] && [ "$1" != "-help" ] && [ "$1" != "-n" ]; then
    error "Unsupported option ($1)" 1 
fi

if [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
    do_help
    exit 0;
fi

container_name=$2

if [[ ! $container_name =~ ^$docker_user ]]; then
    error "Sorry! (Current User: $docker_user). Container ($container_name) is not your container. DO NOT get into other people's containers. Exit!" 0
fi

xhost +local:root 1>/dev/null 2>&1

docker exec \
    -u "${docker_user}" \
    -e HISTFILE=$HOME/.vmc_dc_bash_hist \
    -it "${container_name}" \
    /bin/bash

xhost -local:root 1>/dev/null 2>&1
