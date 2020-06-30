#!/bin/bash

TARGET_MAP=$1
TARGET_KEY=$2
TARGET_VALUE=$3

function exists_configmap {
    local cmname=$1
    kubectl get configmap $cmname --no-headers=true > /dev/null 2>&1
    local err=$?
    return $err
}

function create_configmap {
    local cmname=$1
    kubectl create configmap $cmname
    return 0
}

function update_configmap {
    local cmname=$1
    local key=$2
    local val=$3
    local patch="{\"data\":{\"$key\":\"$val\"}}"
    kubectl patch configmap $cmname --patch=$patch
}

if exists_configmap $TARGET_MAP; then
    # update value 
    echo ConfigMap $TARGET_MAP already exists
else
    # create config map and update value
    create_configmap $TARGET_MAP
fi

update_configmap $TARGET_MAP $TARGET_KEY $TARGET_VALUE