#!/usr/bin/env bash

#!/bin/bash

# Define a sudo wrapper
run_as_root() {
  if [ "$(id -u)" -ne 0 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Check if dockerd is running
if ! pgrep -x "dockerd" > /dev/null
then
    echo "Docker daemon is not running. Starting dockerd in the background..."
    run_as_root dockerd > /dev/null 2>&1 &
else
    echo "Docker daemon is already running."
fi

# For score-k8s AMD64 / x86_64
if ! command -v score-k8s &> /dev/null
then
  echo "score-k8s not found. Installing..."
  [ $(uname -m) = x86_64 ] && curl -sLO "https://github.com/score-spec/score-k8s/releases/download/0.1.18/score-k8s_0.1.18_linux_amd64.tar.gz"
  # For score-k8s ARM64
  [ $(uname -m) = aarch64 ] && curl -sLO "https://github.com/score-spec/score-k8s/releases/download/0.1.18/score-k8s_0.1.18_linux_arm64.tar.gz"
  tar xvzf score-k8s*.tar.gz
  rm score-k8s*.tar.gz README.md LICENSE
  run_as_root mv ./score-k8s /usr/local/bin/score-k8s
  run_as_root chown root: /usr/local/bin/score-k8s
else
  echo "score-k8s is already installed."
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null
then
  echo "kubectl not found. Installing..."
  # For Kubectl AMD64 / x86_64
  [ $(uname -m) = x86_64 ] && curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  # For Kubectl ARM64
  [ $(uname -m) = aarch64 ] && curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
  chmod +x ./kubectl
  run_as_root mv ./kubectl /usr/local/bin/kubectl
else
  echo "kubectl is already installed."
fi

# Check if kind is installed
if ! command -v kind &> /dev/null
then
  echo "kind not found. Installing..."
  # For Kind AMD64 / x86_64
  [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-amd64
  # For ARM64
  [ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-arm64
  chmod +x ./kind
  run_as_root mv ./kind /usr/local/bin/kind
else
  echo "kind is already installed."
fi

# Check if the network already exists and create it if it does not
if ! docker network ls | grep -q 'kind'; then
  docker network create -d=bridge -o com.docker.network.bridge.enable_ip_masquerade=true -o com.docker.network.driver.mtu=1500 --subnet fc00:f853:ccd:e793::/64 kind
else
  echo "Network 'kind' already exists."
fi

# Check if idpbuilder is installed
if ! command -v idpbuilder &> /dev/null
then
  echo "idpbuilder not found. Installing..."
  mkdir -p $HOME/temp
  cd $HOME/temp
  curl -fsSL https://raw.githubusercontent.com/cnoe-io/idpbuilder/main/hack/install.sh | bash
  cd ..
  rm -rf temp
else
  echo "idpbuilder is already installed."
fi

# Set kubectl up to run against the local cluster
kind export kubeconfig --name=localdev

# Run idpbuilder with the specified command and do some initial setup - but only on the first start
if [ "$(kubectl get ns | grep argocd | wc -l)" -ne "1" ]
then
    echo "Running idpbuilder create for the first time... this will take a while"
    idpbuilder create --use-path-routing --package https://github.com/cnoe-io/stacks//ref-implementation
    # Get the gateway API in if we want to work with score-k8s
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
else
    echo "idpbuilder has already been run and inital setup has been done"
fi

# Do some more initial setup - sadly we need this on every start - but it's fast
kubectl get secret -n default idpbuilder-cert -o json | jq -r '.data."ca.crt"' | base64 -d > cnoe-ca.crt
run_as_root cp cnoe-ca.crt /usr/local/share/ca-certificates/
run_as_root update-ca-certificates
git config --global user.name "giteaAdmin"
git config --global credential.helper store
# setup autocomplete for kubectl and nice aliases
run_as_root apt-get update -y && run_as_root apt-get install bash-completion -y
mkdir $HOME/.kube
echo "source <(kubectl completion bash)" >> $HOME/.bashrc
echo "complete -F __start_kubectl k" >> $HOME/.bashrc
echo "alias k='kubectl'" >> $HOME/.bashrc
echo "alias kg='kubectl get'" >> $HOME/.bashrc
echo "alias h='humctl'" >> $HOME/.bashrc
echo "alias sk='score-k8s'" >> $HOME/.bashrc
echo "alias ll='ls -lah --color=auto'" >> $HOME/.bashrc
echo "alias igs='idpbuilder get secrets'" >> $HOME/.bashrc
