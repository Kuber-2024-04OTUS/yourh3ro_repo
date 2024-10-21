# Get vms
IP_VMs=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s")) | .network_interfaces[] | .primary_v4_address.one_to_one_nat.address' )
SSH_PRIVATE_KEY=~/.ssh/id_ed25519

MASTER_IP=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s-master")) | .network_interfaces[0].primary_v4_address.one_to_one_nat.address')
WORKER_IPS=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s-worker")) | .network_interfaces[0].primary_v4_address.one_to_one_nat.address' | paste -s -d' ')

# Install k3s on master node
./k3sup install \
    --ssh-key $SSH_PRIVATE_KEY \
    --ip $MASTER_IP \
    --user yc-user \
    --local-path ./k3s-kubeconfig.yml \
    --cluster \
    --k3s-channel stable \
    --k3s-extra-args '--cluster-cidr 10.42.0.0/16 --service-cidr 10.43.0.0/16 --write-kubeconfig-mode 644'

# install k3s on worker nodes
for WORKER in $WORKER_IPS; do
    ./k3sup join \
        --ssh-key $SSH_PRIVATE_KEY \
        --ip $WORKER \
        --server-ip $MASTER_IP \
        --user yc-user 
done