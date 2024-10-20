#!/bin/bash

FOLDER_ID=$(yc config get folder-id)
SSH_KEY=~/.ssh/id_ed25519.pub


# Create master node
yc compute instance create \
    --folder-id $FOLDER_ID \
    --name otus-k8s-master-0 \
    --hostname otus-k8s-master-0 \
    --labels role=master \
    --platform standard-v2 \
    --zone ru-central1-b \
    --create-boot-disk image-family=ubuntu-2404-lts-oslogin,size=30,type=network-hdd,auto-delete=true \
    --image-folder-id standard-images \
    --memory=8 \
    --cores=2 \
    --core-fraction=20 \
    --preemptible \
    --network-settings type=standard \
    --network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
    --ssh-key $SSH_KEY \
    --metadata serial-port-enable=1 \
    --async

for i in {0..2}; do

    # Create worker nodes
    yc compute instance create \
        --folder-id $FOLDER_ID \
        --name otus-k8s-worker-$i \
        --hostname otus-k8s-worker-$i \
        --labels role=worker \
        --platform standard-v2 \
        --zone ru-central1-b \
        --create-boot-disk image-family=ubuntu-2404-lts-oslogin,size=60,type=network-hdd,auto-delete=true \
        --image-folder-id standard-images \
        --memory=8 \
        --cores=2 \
        --core-fraction=20 \
        --preemptible \
        --network-settings type=standard \
        --network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
        --ssh-key $SSH_KEY \
        --metadata serial-port-enable=1 \
        --async 

done

echo "run \"yc compute instance list\" to check progress"