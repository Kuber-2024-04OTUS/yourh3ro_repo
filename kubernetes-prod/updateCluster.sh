#!/bin/bash
MASTER_IP=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s-master")) | .network_interfaces[0].primary_v4_address.one_to_one_nat.address')
WORKER_IPS=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s-worker")) | .network_interfaces[0].primary_v4_address.one_to_one_nat.address' | paste -s -d' ')

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=30 yc-user@$MASTER_IP '
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring-30.gpg; \
    cat <<EOF | sudo tee /etc/apt/sources.list.d/k8s.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring-30.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF
    sudo apt-get update && \
    sudo apt-mark unhold kubelet kubeadm kubectl && \
    sudo apt-get install -y kubelet=1.30.5-1.1 kubeadm=1.30.5-1.1 kubectl=1.30.5-1.1 && \
    sudo apt-mark hold kubelet kubeadm kubectl && \
    sudo kubeadm upgrade plan && \
    sudo kubeadm upgrade apply v1.30.5 --force && \
    sudo systemctl daemon-reload && \
    sudo systemctl restart kubelet 
    '

for IP in $WORKER_IPS; do
    NODE_NAME=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=30 yc-user@$IP "hostnamectl --static")
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=30 yc-user@$IP "
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring-30.gpg; \
    cat <<EOF | sudo tee /etc/apt/sources.list.d/k8s.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring-30.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF
    sudo apt-get update && \
    sudo apt-mark unhold kubelet kubeadm kubectl && \
    sudo apt-get install -y kubelet=1.30.5-1.1 kubeadm=1.30.5-1.1 kubectl=1.30.5-1.1 && \
    sudo apt-mark hold kubelet kubeadm kubectl && \
    sudo kubeadm upgrade node && \
    sudo systemctl daemon-reload && \
    sudo systemctl restart kubelet && \
    kubectl uncordon $NODE_NAME
    "
done