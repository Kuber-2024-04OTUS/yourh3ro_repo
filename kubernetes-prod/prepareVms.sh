# Get vms
IP_VMs=$(yc compute instance list --format=json | jq -r '.[] | select(.name | startswith("otus-k8s")) | .network_interfaces[] | .primary_v4_address.one_to_one_nat.address' )

# check ping 
for i in $IP_VMs; do
    ping -c 1 -W 1 $i > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then 
        echo "$i is down"
    fi
done

# check ssh
for i in $IP_VMs; do
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i 'exit 0'
    if [[ $? -ne 0 ]]; then 
        echo "$i is not sshable"
    fi
done

# disable swap
for i in $IP_VMs; do
    ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
    sudo swapoff -a && \
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
done

# install common tools
for i in $IP_VMs; do
    ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
        sudo apt-get update && \
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
        "
done

# install and init containerd
for i in $IP_VMs; do
    ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    sudo apt-get update && \
    sudo apt-get install -y containerd && \
    sudo containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/g' | sudo tee /etc/containerd/config.toml; \
    sudo systemctl restart containerd 
    "
done

# init modules
for i in $IP_VMs; do
    ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
    rm -f /etc/modules-load.d/containerd.conf && \
    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay && \
    sudo modprobe br_netfilter && \
    rm -f /etc/sysctl.d/99-kubernetes-cri.conf && \
    cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sudo sysctl --system
    "
done


# install k8s tools
for i in $IP_VMs; do
    ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null yc-user@$i "
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
    cat <<EOF | sudo tee /etc/apt/sources.list.d/k8s.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /
EOF
    sudo apt-get update && \
    sudo apt-get install -y kubelet kubeadm kubectl && \
    sudo apt-mark hold kubelet kubeadm kubectl
    "
done