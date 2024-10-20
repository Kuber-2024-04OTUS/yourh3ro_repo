# Get vms
IP_VMs=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s")) | .network_interfaces[] | .primary_v4_address.one_to_one_nat.address' )
SSH_PRIVATE_KEY=~/.ssh/id_ed25519

# # check ping 
# for i in $IP_VMs; do
#     ping -c 1 -W 1 $i > /dev/null 2>&1
#     if [[ $? -ne 0 ]]; then 
#         echo "$i is down"
#     fi
# done

# # check ssh
# for i in $IP_VMs; do
#     ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i 'exit 0'
#     if [[ $? -ne 0 ]]; then 
#         echo "$i is not sshable"
#     fi
# done

# # disable swap
# for i in $IP_VMs; do
#     ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
#     sudo swapoff -a && \
#     sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
# done

# # ufw settings
# for i in $IP_VMs; do
#     ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
#     sudo ufw allow 6443/tcp                 # apiserver
#     sudo ufw allow from 10.42.0.0/16 to any # pods
#     sudo ufw allow from 10.43.0.0/16 to any # services
# "
# done

# # install common tools
# for i in $IP_VMs; do
#     ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
#         sudo apt-get update && \
#         sudo apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common jq
#         "
# done

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