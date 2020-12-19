#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
function warning()
{
    local _msg=$1
    echo "-W- $_msg"
    return 0
}
function _create_user_account() {
  local user_name="$1"
  local uid="$2"
  local group_name="$3"
  local gid="$4"

  if grep -q $group_name /etc/group; then
    gid=`$DIR/get_grpid.pl $group_name`
    warning "group ($group_name) has existed. Get it's gid ($gid)"
  else
    addgroup --gid "${gid}" "${group_name}"
  fi

  adduser --disabled-password --force-badname --gecos '' \
    "${user_name}" --uid "${uid}" --gid "${gid}" # 2>/dev/null

  usermod -aG sudo "${user_name}"
  usermod -aG video "${user_name}"
}

function setup_user_bashrc() {
  local uid="$1"
  local gid="$2"
  local user_home="/home/$3"
  # cp -rf /etc/skel/.{profile,bash*} "${user_home}"
  local RCFILES_DIR="/opt/apollo/rcfiles"
  local rc
  if [[ -d "${RCFILES_DIR}" ]]; then
    for entry in ${RCFILES_DIR}/*; do
      rc=$(basename "${entry}")
      if [[ "${rc}" = user.* ]]; then
        cp -rf "${entry}" "${user_home}/${rc##user}"
      fi
    done
  fi
  # Set user files ownership to current user, such as .bashrc, .profile, etc.
  # chown -R "${uid}:${gid}" "${user_home}"
  chown -R "${uid}:${gid}" ${user_home}/.*
}

function setup_user_account_if_not_exist() {
  local user_name="$1"
  local uid="$2"
  local group_name="$3"
  local gid="$4"
  if grep -q "^${user_name}:" /etc/passwd; then
    warning "User ${user_name} already exist. Skip setting user account."
    return
  fi
  _create_user_account "$@"
  setup_user_bashrc "${uid}" "${gid}" "${user_name}"
}

function grant_device_permissions() {
  # setup GPS device
  [ -e /dev/novatel0 ] && chmod a+rw /dev/novatel0
  [ -e /dev/novatel1 ] && chmod a+rw /dev/novatel1
  [ -e /dev/novatel2 ] && chmod a+rw /dev/novatel2

  [ -e /dev/ttyACM0 ] && chmod a+rw /dev/ttyACM0
  [ -e /dev/imu ] && chmod a+rw /dev/imu

  # setup camera device
  [ -e /dev/camera/obstacle ] && chmod a+rw /dev/camera/obstacle
  [ -e /dev/camera/trafficlights ] && chmod a+rw /dev/camera/trafficlights

  # setup audio device
  [ -e /dev/snd ] && usermod -a -G audio "$1"
}

##===================== Main ==============================##
function main() {
  local user_name="$1"
  local uid="$2"
  local group_name="$3"
  local gid="$4"

  if [ "${uid}" != "${gid}" ]; then
    warning "uid(${uid}) != gid(${gid}) found."
  fi
  if [ "${user_name}" != "${group_name}" ]; then
    warning "user_name(${user_name}) != group_name(${group_name}) found."
  fi
  setup_user_account_if_not_exist "$@"
  grant_device_permissions "${user_name}"
}

main "${DOCKER_USER}" "${DOCKER_USER_ID}" "${DOCKER_GRP}" "${DOCKER_GRP_ID}"
