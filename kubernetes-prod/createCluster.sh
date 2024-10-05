#!/bin/bash

# --- Configure master node ---

MASTER_IP=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s-master")) | .network_interfaces[0].primary_v4_address.one_to_one_nat.address')
WORKER_IPS=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s-worker")) | .network_interfaces[0].primary_v4_address.one_to_one_nat.address' | paste -s -d' ')

# Initialize Kubernetes on master node
KUBEADM_INIT_TEXT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=30 yc-user@$MASTER_IP 'sudo kubeadm init --pod-network-cidr=10.244.0.0/16')
KUBEADM_JOIN_CMD=$(echo $KUBEADM_INIT_TEXT | grep -oE 'kubeadm join (.)*' | tr -d '\\')

# Save join command to a file
echo $KUBEADM_JOIN_CMD > kubeadm_join.cmd

# Copy configuration file to master node
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=30 yc-user@$MASTER_IP '
  mkdir -p $HOME/.kube && \
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
  sudo chown $(id -u):$(id -g) $HOME/.kube/config'

# --- Install Flannel on master node ---

# Install Flannel
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null flannel.yaml yc-user@$MASTER_IP:/tmp/flannel.yaml
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=30 yc-user@$MASTER_IP 'kubectl apply -f /tmp/flannel.yaml'

# --- Configure worker nodes ---

# Join worker nodes to the cluster
for IP in $WORKER_IPS; do
  ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 yc-user@$IP "sudo $KUBEADM_JOIN_CMD"
done

# Configure kubectl on worker nodes
for IP in $WORKER_IPS; do
  # Copy the kubeconfig from master node
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$MASTER_IP:/home/yc-user/.kube/config yc-user@$IP:/home/yc-user/.kube/config

  # Create directory and move config file
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$IP '
    mkdir -p $HOME/.kube && \
    sudo mv /home/yc-user/.kube/config ~/.kube/config && \
    sudo chown $(id -u):$(id -g) ~/.kube/config'
done
