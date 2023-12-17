#!/bin/bash
if ! [ $USER == "root" ]
then
    echo "Run this script as superuser."
    exit
fi
mode=0
while getopts "r" flag; do
    case $flag in
        r)
            mode=1
        ;;
        \?)
            exit
        ;;
    esac
done

if [ $mode == 0 ]
then
    if [ -f ./.safe_data ]
    then
        echo "Safe is already open."
        exit
    fi
    GREEN="\033[0;032m";
    NC="\033[0;0m";
    disk="./file_safe.img";
    partition="p1"
    mount_flags="-o compress=zstd:15"
    lo_device="$(losetup -fP --show $disk)"
    fullpartition="$lo_device$partition"
    luks_uuid=$(cryptsetup luksUUID "$fullpartition")
    
    
    cryptsetup luksOpen "$fullpartition" luks-$luks_uuid
    fs_uuid="$(blkid -o value -s UUID /dev/mapper/luks-$luks_uuid)"
    
    folder="/run/media/$SUDO_USER/$fs_uuid"
    mkdir -p $folder
    mount $mount_flags /dev/mapper/luks-$luks_uuid "$folder"
    chmod 777 "$folder"
    py_script="import json; data = {\"luks-device\": \"luks-$luks_uuid\", \"mountpoint\": \"$folder\", \"lo_device\": \"$lo_device\"}; f = open(\".safe_data\", \"w\"); f.write(json.dumps(data)); f.close()"
    python3 -c "$py_script";
elif [ $mode == 1 ]
then
    py_script="import json; f = open(\".safe_data\", 'r'); data = json.loads(f.read()); f.close(); print(data['mountpoint'] + ' ' + data['luks-device'] + ' ' + data['lo_device'])"
    session_data=$(python3 -c "$py_script")
    split_data=($session_data)
    mountpoint=${split_data[0]}
    luks_device=${split_data[1]}
    lo_device=${split_data[2]}
    error=0
    umount $mountpoint
    if ! [ $? -eq 0 ]; then
        error=1
    fi
    cryptsetup luksClose /dev/mapper/$luks_device
    if ! [ $? -eq 0 ]; then
        error=1
    fi
    if ! [ $? -eq 0 ]; then
        error=1
    fi
    if [ $error == 1 ]; then
        exit
    else
        losetup -d "$lo_device"
    fi
    rm -f .safe_data
fi
