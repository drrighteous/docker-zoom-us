#!/bin/bash
set -e

USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

RC_US_USER=ringcentral

install_ringcentral() {
  echo "Installing ringcentral-wrapper..."
  install -m 0755 /var/cache/ringcentral/ringcentral-wrapper /target/
  echo "Installing ringcentral..."
  ln -sf ringcentral-wrapper /target/ringcentral
}

uninstall_ringcentral_us() {
  echo "Uninstalling ringcentral-wrapper..."
  rm -rf /target/ringcentral-wrapper
  echo "Uninstalling zoom-us..."
  rm -rf /target/ringcentral
}

create_user() {
  # create group with USER_GID
  if ! getent group ${RC_US_USER} >/dev/null; then
    groupadd -f -g ${RC_GID} ${RC_US_USER} >/dev/null 2>&1
  fi

  # create user with USER_UID
  if ! getent passwd ${RC_US_USER} >/dev/null; then
    adduser --disabled-login --uid ${USER_UID} --gid ${USER_GID} \
      --gecos 'RingCentral' ${RC_US_USER} >/dev/null 2>&1
  fi
  chown ${RC_US_USER}:${RC_US_USER} -R /home/${RC_US_USER}
  adduser ${RC_US_USER} sudo
}

grant_access_to_video_devices() {
  for device in /dev/video*
  do
    if [[ -c $device ]]; then
      VIDEO_GID=$(stat -c %g $device)
      VIDEO_GROUP=$(stat -c %G $device)
      if [[ ${VIDEO_GROUP} == "UNKNOWN" ]]; then
        VIDEO_GROUP=rcvideo
        groupadd -g ${VIDEO_GID} ${VIDEO_GROUP}
      fi
      usermod -a -G ${VIDEO_GROUP} ${RC_US_USER}
      break
    fi
  done
}

launch_ringcentral() {
  cd /home/${RC_US_USER}
  exec sudo -HEu ${RC_US_USER} PULSE_SERVER=/run/pulse/native QT_GRAPHICSSYSTEM="native" $@
}

case "$1" in
  install)
    install_ringcentral
    ;;
  uninstall)
    uninstall_ringcentral
    ;;
  ringcentral)
    create_user
    grant_access_to_video_devices
    echo "$1"
    launch_ringcentral $@
    ;;
  *)
    exec $@
    ;;
esac
