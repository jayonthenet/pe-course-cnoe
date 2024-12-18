#!/usr/bin/env bash

# Check if dockerd is running
if ! pgrep -x "dockerd" > /dev/null
then
    echo "Docker daemon is not running. Starting dockerd in the background..."
    sudo dockerd > /dev/null 2>&1 &
else
    echo "Docker daemon is already running."
fi

# For Kubectl AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# For Kubectl ARM64
[ $(uname -m) = aarch64 ] && curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# For Kind AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -sLo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
# For Kind ARM64
[ $(uname -m) = aarch64 ] && curl -sLo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# setup autocomplete for kubectl and alias k
sudo apt-get update -y && sudo apt-get install bash-completion -y
mkdir $HOME/.kube
echo "source <(kubectl completion bash)" >> $HOME/.bashrc
echo "alias k=kubectl" >> $HOME/.bashrc
echo "complete -F __start_kubectl k" >> $HOME/.bashrc
docker network create -d=bridge -o com.docker.network.bridge.enable_ip_masquerade=true -o com.docker.network.driver.mtu=1500 --subnet fc00:f853:ccd:e793::/64 kind

# Install idpbuilder
curl -fsSL https://raw.githubusercontent.com/cnoe-io/idpbuilder/main/hack/install.sh | bash

# Run idpbuilder with the specified command
idpbuilder create --use-path-routing --package https://github.com/cnoe-io/stacks//ref-implementation