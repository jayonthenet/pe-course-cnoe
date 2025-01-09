#!/usr/bin/env bash

# Check if dockerd is running
if ! pgrep -x "dockerd" > /dev/null
then
    echo "Docker daemon is not running. Starting dockerd in the background..."
    sudo dockerd > /dev/null 2>&1 &
else
    echo "Docker daemon is already running."
fi

# For score-k8s AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -sLO "https://github.com/score-spec/score-k8s/releases/download/0.1.18/score-k8s_0.1.18_linux_amd64.tar.gz"
# For score-k8s ARM64
[ $(uname -m) = aarch64 ] && curl -sLO "https://github.com/score-spec/score-k8s/releases/download/0.1.18/score-k8s_0.1.18_linux_arm64.tar.gz"
tar xvzf score-k8s*.tar.gz
rm score-k8s*.tar.gz README.md LICENSE
sudo mv ./score-k8s /usr/local/bin/score-k8s
sudo chown root: /usr/local/bin/score-k8s

# For Kubectl AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# For Kubectl ARM64
[ $(uname -m) = aarch64 ] && curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# For Kind AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-arm64
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
mkdir -p $HOME/temp
cd $HOME/temp
curl -fsSL https://raw.githubusercontent.com/cnoe-io/idpbuilder/main/hack/install.sh | bash
cd ..
rm -rf temp

# Run idpbuilder with the specified command
idpbuilder create --use-path-routing --package https://github.com/cnoe-io/stacks//ref-implementation

## Prep env
# Set kubectl up to run against the local cluster
kind export kubeconfig --name=localdev
# Get the gateway API in if we want to work with score-k8s
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
# ATTENTION WITH THIS ONE - we need this at least for Git to be able to interact with the self-signed cert
kubectl get secret -n default idpbuilder-cert -o json | jq -r '.data."ca.crt"' | base64 -d > cnoe-ca.crt
sudo cp cnoe-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
git config --global user.name "giteaAdmin"
git config --global credential.helper store
# Set some nice aliases
echo "alias k='kubectl'" >> $HOME/.bashrc
echo "alias kg='kubectl get'" >> $HOME/.bashrc
echo "alias h='humctl'" >> $HOME/.bashrc
echo "alias sk='score-k8s'" >> $HOME/.bashrc
