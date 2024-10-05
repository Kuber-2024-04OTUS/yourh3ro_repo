#!/bin/bash

yc compute instance list --format=json | jq -r '.[].id' | xargs yc compute instance delete --async