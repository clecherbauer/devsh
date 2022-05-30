#!/usr/bin/env bash
set -e

REPLACEMENT_UID='978654321'

function user_exists() {
    id "$1" > /dev/null 2>&1
}

function modify_or_create_user() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Please set USERNAME as \$1 and UID as $\2!"
        exit 1
    fi
    local USERNAME="$1"
    local _UID="$2"

    if ! user_exists "$USERNAME"; then
        local _HOME="/home/$USERNAME"
        mkdir "$_HOME"
        useradd "$USERNAME" -d "$_HOME" --no-log-init -u "$_UID"
        chown -R $USERNAME:$USERNAME $_HOME
    fi

    if user_exists "$_UID"; then
        modify_user "$(id -nu "$_UID")" "$REPLACEMENT_UID"
        modify_user "$USERNAME" "$_UID"
    elif user_exists "$USERNAME"; then
        modify_user "$USERNAME" "$_UID"
    fi
}

function modify_user() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Please set USERNAME as \$1 and UID as $\2!"
        exit 1
    fi
    local USERNAME=$1
    local _UID=$2

    if ! user_exists "$USERNAME"; then
        echo "User does not exist: '$USERNAME'"
        exit 1
    fi
    local OLD_GROUP_NAME=$(id -gn "$USERNAME")
    local OLD_UID=$(id -u "$USERNAME")
    local OLD_GID=$(id -g "$USERNAME")
    local _HOME="$(eval echo ~$USERNAME)"

    userdel "$USERNAME"
    useradd "$USERNAME" -d "$_HOME" --no-log-init -u "$_UID"
    groupmod -g "$_UID" "$OLD_GROUP_NAME"
    if [ ! -d "$_HOME" ]; then
      mkdir -p "$_HOME"
    fi
    find "$_HOME" -ignore_readdir_race -user "$OLD_UID" -exec chown -h "$_UID" {} \;
    find "$_HOME" -ignore_readdir_race -group "$OLD_GID" -exec chgrp -h "$_UID" {} \;
    usermod -g "$_UID" "$USERNAME"
}

function export_uid_host_from_dotenv() {
    for dotenv in $(find / -name *.env); do
        source "$dotenv"
        if [ ! -z "$UID_HOST" ]; then
            export "UID_HOST=$UID_HOST"
        fi
    done
}

USER_NAME_TO_SWITCH="$1"
USER_ID_TO_SWITCH="$2"

if [ ! -z "$USER_NAME_TO_SWITCH" ] && [ -z "$USER_ID_TO_SWITCH" ]; then
    export_uid_host_from_dotenv
    if [ -z "$UID_HOST" ]; then
        echo "Variable UID_HOST not present, please check your .env!"
        exit 1
    fi
    modify_or_create_user "$USER_NAME_TO_SWITCH" "$UID_HOST"
else
    modify_or_create_user "$USER_NAME_TO_SWITCH" "$USER_ID_TO_SWITCH"
fi
