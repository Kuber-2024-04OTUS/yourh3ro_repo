#!/bin/bash

for id in $(yc compute instance list --format=json | jq -r '.[].id'); do
    yc compute instance stop $id --async
done
