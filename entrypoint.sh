#!/usr/bin/env bash
########################################################################################################################
# Common helpers
########################################################################################################################
# Err on anything
# Note: bluetoothd might fail
set -e

helpers::dbus(){
  # On container restart, cleanup the crap
  rm -f /run/dbus/pid
  # Not really useful, but then
  dbus-uuidgen --ensure

  # https://linux.die.net/man/1/dbus-daemon-1
  dbus-daemon --system

  until [ -e /run/dbus/system_bus_socket ]; do
    sleep 1s
  done
}

helpers::avahi(){
  # On container restart, cleanup the crap
  rm -f /run/avahi-daemon/pid

  # Set the hostname, if we have it
  sed -i'' -e "s,%AVAHI_NAME%,$AVAHI_NAME,g" /etc/avahi/avahi-daemon.conf

  # https://linux.die.net/man/8/avahi-daemon
  avahi-daemon --daemonize --no-chroot
}

helpers::bluetooth(){
  bluetoothd --noplugin=sap -n &
  sleep 10

  rm -f /run/bluealsa/hci0
  bluealsa --device=hci0 &
  # Errrrrrrr
  sleep 10
}

helpers::pair(){
  local device="$1"
  printf "pair %s\ntrust %s\nconnect %s\nquit" "$device" "$device" "$device" | bluetoothctl
  if ! $?; then
    printf "FAILED PAIRING\n"
  fi
  # hcitool scan
  # rfcomm connect hci0 $device 2?
}

helpers::register(){
  local device="$1"
  local nick="$2"
  local desc="$3"

#  cat <<-EOF >> "/etc/asound.conf"
  cat <<-EOF > "/root/.asoundrc"
defaults.bluealsa.service "org.bluealsa"
defaults.bluealsa.device "$device"
defaults.bluealsa.profile "a2dp"
defaults.bluealsa.delay 10000

pcm.$nick {
  type plug
  slave {
    pcm {
      type bluealsa
      device "$device"
      profile "a2dp"
    }
  }
  hint {
    show on
    description "$desc"
  }
}

ctl.$nick {
  type bluetooth
}
EOF
}

if [ "$X_BLUETOOTH" ]; then
  helpers::dbus
  helpers::bluetooth

  BT_DEVICE=${BT_DEVICE:-"C0:28:8D:02:76:8C"}
  BT_NICK=${BT_NICK:-aquamuse}
  BT_DESC=${BT_DESC:-The Aqua Muse}
  if [ "$1" == "pair" ]; then
    helpers::register "$BT_DEVICE" "$BT_NICK" "$BT_DESC"
    exit
  fi
fi

exec ./Bridge/RoonBridge
