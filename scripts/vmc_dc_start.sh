#!/usr/bin/env bash

SUPPORTED_ARCHS=(x86_64 aarch64)
HOST_ARCH="$(uname -m)"
HOST_OS="$(uname -s)"

DOCKER_RUN="docker run"

USE_GPU_HOST=0
USER_AGREED="no"

tag="latest"
SHM_SIZE="2G"

network="host"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function show_usage() {
    filename=$(basename $0)
    cat <<EOF
Usage: $filename [options] ...
OPTIONS:
    -h, --help             Display this help and exit.
    -i, --image <IMAGE>    Docker image name.
    -t, --tag <TAG>        Specify docker image with tag <TAG> to start.
    -n, --name <name>      Container name.
    --network <name>       Default: host
    --shm-size <bytes>     Size of /dev/shm . Passed directly to "docker run"
    stop                   Stop all running containers which belong to you.
EOF
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

function warning()
{
    local _msg=$1
    echo "-W- $_msg"
    return 0
}

function info()
{
    local _msg=$1
    echo "-I- $_msg"
    return 0
}

function stop_all_containers_for_user() {
    local force="$1"
    local running_containers
    running_containers="$(docker ps -a --format '{{.Names}}')"
    for container in ${running_containers[*]}; do
        if [[ "${container}" =~ ${USER}_.* ]]; then
            #printf %-*s 70 "Now stop container: ${container} ..."
            #printf "\033[32m[DONE]\033[0m\n"
            #printf "\033[31m[FAILED]\033[0m\n"
            info "Now stop container ${container} ..."
            if docker stop "${container}" >/dev/null; then
                if [[ "${force}" == "-f" || "${force}" == "--force" ]]; then
                    docker rm -f "${container}" >/dev/null
                fi
                info "Done."
            else
                warning "Failed."
            fi
        fi
    done
    if [[ "${force}" == "-f" || "${force}" == "--force" ]]; then
        info "OK. Done stop and removal"
    else
        info "OK. Done stop."
    fi
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
    shm_size=""

    while [ $# -gt 0 ]; do
        local opt="$1"
        shift
        case "${opt}" in
            -i | --image)
                image_name="$1"
                shift
                _optarg_check_for_opt "${opt}" "${image_name}"
                ;;
            -t | --tag)
                tag="$1"
                shift
                _optarg_check_for_opt "${opt}" "${tag}"
                ;;

            -h | --help)
                show_usage
                exit 1
                ;;

            -n | --name)
                container_name="$1"
                shift
                _optarg_check_for_opt "${opt}" "${container_name}"
                ;;

            --shm-size)
                shm_size="$1"
                shift
                _optarg_check_for_opt "${opt}" "${shm_size}"
                ;;

            --network)
                network="$1"
                shift
                _optarg_check_for_opt "${opt}" "$network"
                ;;

            stop)
                stop_all_containers_for_user "-f"
                exit 0
                ;;
            *)
                warning "Unknown option: ${opt}"
                exit 2
                ;;
        esac
    done # End while loop

    [[ -n "${shm_size}" ]] && SHM_SIZE="${shm_size}"
}


function determine_gpu_use_host() {
    if [ "${HOST_ARCH}" = "aarch64" ]; then
        if lsmod | grep -q "^nvgpu"; then
            USE_GPU_HOST=1
        fi
    else
        # Check nvidia-driver and GPU device
        local nv_driver="nvidia-smi"
        if [ ! -x "$(command -v ${nv_driver})" ]; then
            warning "No nvidia-driver found. CPU will be used"
        elif [ -z "$(eval ${nv_driver})" ]; then
            warning "No GPU device found. CPU will be used."
        else
            USE_GPU_HOST=1
        fi
    fi

    # Try to use GPU inside container
    local nv_docker_doc="https://github.com/NVIDIA/nvidia-docker/blob/master/README.md"
    if [ ${USE_GPU_HOST} -eq 1 ]; then
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
        if [[ -x "$(which nvidia-container-toolkit)" ]]; then
            if dpkg --compare-versions "${DOCKER_VERSION}" "ge" "19.03"; then
                DOCKER_RUN="docker run --gpus all"
            else
                warning "You must upgrade to Docker-CE 19.03+ to access GPU from container!"
                USE_GPU_HOST=0
            fi
        elif [[ -x "$(which nvidia-docker)" ]]; then
            DOCKER_RUN="nvidia-docker run"
        else
            USE_GPU_HOST=0
            warning "Cannot access GPU from within container. Please install " \
                "latest Docker and NVIDIA Container Toolkit as described by: "
            warning "  ${nv_docker_doc}"
        fi
    fi
}

function post_run_setup() {
    if [ "${USER}" != "root" ]; then
        cp $DIR/docker_start_user.sh /tmp 
        cp $DIR/get_grpid.pl /tmp 
        cp $DIR/centos_add_user.sh /tmp 
        docker exec -u root "${container_name}" bash -c '/tmp/docker_start_user.sh'
        rm /tmp/docker_start_user.sh
        rm /tmp/get_grpid.pl
        rm /tmp/centos_add_user.sh
    fi
}

function main() {

    parse_arguments "$@"

    info "Determine whether host GPU is available ..."
    determine_gpu_use_host
    info "USE_GPU_HOST: ${USE_GPU_HOST}"


    local local_host="$(hostname)"
      
    if [ -z ${DISPLAY+x} ]; then 
        display_opt=""
    else      
        display_opt="-e DISPLAY=${DISPLAY:-:0}"
        info "docker's env DISPLAY=$display_opt"
    fi

    local user="${USER}"

    if [[ ! $container_name =~ ^$user ]]; then
        container_name="${user}_$container_name"
    fi

    info "Starting docker container \"${container_name}\" ..."

    local uid="$(id -u)"
    local group="$(id -g -n)"
    local gid="$(id -g)"

    ${DOCKER_RUN} -itd \
        --name "${container_name}" ${display_opt} \
        -e DOCKER_USER="${user}" \
        -e USER="${user}" \
        -e DOCKER_USER_ID="${uid}" \
        -e DOCKER_GRP="${group}" \
        -e DOCKER_GRP_ID="${gid}" \
        -e DOCKER_IMG="${image_name}" \
        -e HOST_OS="${HOST_OS}" \
        -e USE_GPU_HOST="${USE_GPU_HOST}" \
        -e NVIDIA_VISIBLE_DEVICES=all \
        -e NVIDIA_DRIVER_CAPABILITIES=compute,video,graphics,utility \
        --net ${network} \
        -w /home/${user} \
        --add-host "${local_host}:127.0.0.1" \
        --hostname "${container_name}" \
        --shm-size "${SHM_SIZE}" \
        --pid=host \
        -v /dev/null:/dev/raw1394 \
        -v /tmp:/tmp \
        ${image_name}:${tag} \
        /bin/bash

    if [ $? -ne 0 ]; then
        error "Failed to start docker container \"${container_name}\" based on image: ${image_name}:${tag}" 0
        exit 1
    fi

    post_run_setup

    info "Congratulations! You have successfully started the container ($container_name) based on image: ($image_name:$tag)"
    info "To login into the newly created ${container_name} container, please run the following command:"
    info "  vmc_dc_enter.sh -n $container_name"
    info "Enjoy!"
}

main "$@"
