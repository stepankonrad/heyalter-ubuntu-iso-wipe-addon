#!/bin/bash

ROOT=/cdrom/wipe

install_tools () {
  echo $BASH_SOURCE $FUNCNAME $1

  apt-get -y install $ROOT/*.deb
}

populate_device_list () {
  DISKDEV_LIST=$(lsblk -AdnPo PATH,TYPE,MODEL,VENDOR,SIZE,ROTA,RM -x SIZE | while read LINE; do
    eval $LINE
    if (( $RM == 1 )); then # skip removable devices
      continue
    fi
    if [[ "$TYPE" =~ ^(loop|rom|part|md)$ ]]; then # skip specific types of devices
      continue
    fi
    echo $PATH
  done)
  echo $BASH_SOURCE $FUNCNAME $DISKDEV_LIST
}

wipe_nvme () {
  echo $BASH_SOURCE $FUNCNAME $1

  nvme format --ses=1 --force $1
  if [ $? -eq 0 ]; then return 0; fi

  systemctl suspend -i
  nvme format --ses=1 --force $1
  if [ $? -eq 0 ]; then return 0; fi

  return 1
}

wipe_ata () {
  echo $BASH_SOURCE $FUNCNAME $1

  $ROOT/ata-secure-erase.sh -f $1
  if [ $? -eq 0 ]; then return 0; fi

  systemctl suspend -i
  $ROOT/ata-secure-erase.sh -f $1
  if [ $? -eq 0 ]; then return 0; fi

  return 1
}

fast_wipe_all () {
  RESULT=0
  for d in $DISKDEV_LIST
  do
    case "$d" in 
      *nvme*)
        wipe_nvme $d
        if [ $? -ne 0 ]; then RESULT=1; fi;;
      *)
        wipe_ata $d
        if [ $? -ne 0 ]; then RESULT=1; fi;;
    esac

  done
  return $RESULT
}

wipe_nwipe () { 
  echo $BASH_SOURCE $FUNCNAME

  nwipe -m random --nogui --verify=off --autonuke --nousb

  if [ $? -ne 0 ]; then exit 1; fi
}

check_all_zero () {
  echo $BASH_SOURCE $FUNCNAME

  nwipe -m verify_zero --nogui --autonuke --nousb

  if [ $? -ne 0 ]; then exit 1; fi
}

main () {
  install_tools
  populate_device_list
  fast_wipe_all

  # fallback
  if [ $? -ne 0 ]; then
    wipe_nwipe
  fi

  check_all_zero
}

main
