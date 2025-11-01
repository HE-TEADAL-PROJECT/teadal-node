#!/bin/bash
set -euo pipefail

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Mandatory options:"
    echo "  -d <repo_dir>     Specify the directory with the repo clone"
    echo "  -r <repo_url>     Specify the repoURL"
    echo "Options:"
    echo "  -b <branch>       Specify a branch"
    echo "  -h                Display this help message"
}

main() {
    parse_options "$@"
    log "Script started with options:\n\trepo_dir=$repo_dir\n\trepo_url=$repo_url\n\tbranch=$branch"
    setup_microk8s
    setup_storage
    setup_mesh
    exit 0 # TODO: comment before commit until fully tested
}

### Utilities scripts
# Colors and logging functions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TEADAL_LOG_DIR="${TEADAL_LOG_DIR:-/tmp}"
logfile="$TEADAL_LOG_DIR/install-teadal.log"

log() { echo "${GREEN}[INFO]${NC}$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $logfile; }
error() { echo "${RED}[ERROR]${NC}$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $logfile >&2; }
error_exit() {
    error "$1"
    exit "${2:-1}"
}

# Global variables
repo_dir="$(pwd)" # Directory with the repo clone
repo_url="$(git config --get remote.origin.url 2>/dev/null || echo '')"
# Url of the repo
branch=""       # Branch of the repo
hostname_dir="" # Directory with generated storage pv

parse_options() {
    while getopts "d:u:b:h" opt; do
        case $opt in
        d) repo_dir="$OPTARG" ;;
        u) repo_url="$OPTARG" ;;
        b) branch="$OPTARG" ;;
        h)
            usage
            exit 0
            ;;
        ?)
            error "Invalid option: $OPTARG"
            exit 1
            ;;
        esac
    done

    if [ -z "$HOSTNAME" ]; then
        error "HOSTNAME variable not defined"
        exit 1
    fi
}

setup_microk8s() {
    log "Setting up microk8s..."

    # If microk8s is not installed install it
    if ! command -v microk8s &>/dev/null; then
        log "microk8s not found, installing..."
        sudo mkdir -p /var/snap/microk8s/common/ || error_exit "Failed to create /var/snap/microk8s/common/."
        sudo cp "$repo_dir/utils/microk8s-config.yaml" /var/snap/microk8s/common/.microk8s.yaml || error_exit "Failed to copy microk8s configuration file."
        sudo snap install microk8s --classic --channel=1.27/stable || error_exit "Failed to install microk8s."
    else
        log "microk8s found, updating configuration..."
        microk8s start
        sudo snap set microk8s config="$(cat $repo_dir/utils/microk8s-config.yaml)"
    fi

    # Setup permissions
    sudo usermod -a -G microk8s $USER
    mkdir -p ~/.kube
    chmod 0700 ~/.kube
    log "User $USER added to microk8s group. You may need to log out and log back in for this to take effect."
    log "Waiting for microk8s to be ready..."
    sudo microk8s status --wait-ready &>/dev/null || error_exit "microk8s is not ready."
    sudo microk8s config >~/.kube/config
    export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config
    if ! command -v kubectl &>/dev/null; then
        log "kubectl not found, aliasing it to microk8s.kubectl"
        sudo snap alias microk8s.kubectl kubectl || error_exit "Failed to alias kubectl."
    fi
    log "Setup microk8s completed."
}

setup_mesh() {
    log "Setting up mesh infra..."

    istioctl install -y --verify -f "$repo_dir"/deployment/mesh-infra/istio/profile.yaml
    kubectl label namespace default istio-injection=enabled || error_exit "Failed to label default namespace for istio injection."
}

setup_storage() {
    log "Creating storage directories..."
    sudo mkdir -p /mnt/data || error_exit "Failed to create /mnt/data directory."
    sudo chmod 777 /mnt/data || error_exit "Failed to set permissions on /mnt/data."
    sudo mkdir -p /mnt/data/d{1..10} || error_exit "Failed to create /mnt/data directories."

    log "Setting up Persistent Volumes..."
    pv_tool="$repo_dir/utils/create-local-pv.sh"
    bash "$pv_tool" /mnt/data/d1 -s 20Gi -n local-pv-1 || error_exit "Failed to create Persistent Volume for d1."
    for i in {2..10}; do
        bash "$pv_tool" "/mnt/data/d$i" -s 10Gi -n "local-pv-$i" || error_exit "Failed to create Persistent Volume for d$i."
    done

    log "Local-static-provisioner storage setup completed."
}

main "$@"

echo "setting up microk8s storage"

sudo mkdir -p /mnt/disk/d{1..10}
sudo chmod -R 777 /mnt/disk
node.config -microk8s pv 1:20 8:10
hostname_dir=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
echo "pippo"
echo "$hostname_dir"
mv "$hostname_dir" "$repo_dir"/deployment/mesh-infra/storage/pv/local/

# change the kustomizefile for storage ports
file="$repo_dir""/deployment/mesh-infra/storage/pv/local/kustomization.yaml"
kustomizationfile_dir="$repo_dir""/deployment/mesh-infra/storage/pv/local/"
substring="\- <HOST_NAME>"
replacement=$(echo "-" $hostname_dir)

# Check if the file exists
if [ ! -f "$file" ]; then
    echo "Error: File '$file' does not exist."
    exit 1
fi

# Check if the file contains a line with the given substring
if grep -q "$substring" "$file"; then
    sed -i.bak "s/^$substring.*/$replacement/" "$file" && rm "$file".bak
else
    substring=$(echo "\-" "$hostname_dir")
    if grep -q "$substring" "$file"; then
        echo "folder already included in the  kustomizationfile"
    else
        echo "$replacement" >>"$file"
    fi
fi

kustomize build "$kustomizationfile_dir" | kubectl apply -f -

kubectl get pv

echo "microk8s storage set"

exit 0

echo "installing istio"

istioctl install -y --verify -f "$repo_dir"/deployment/mesh-infra/istio/profile.yaml
kubectl label namespace default istio-injection=enabled

kubectl get pod -A

echo "istio installed"

echo "installing ArgoCD"

# change the kustomizefile for argocd repo
file="$repo_dir""/deployment/mesh-infra/argocd/projects/base/app.yaml"
substring="repoURL"
replacement=$(echo "    repoURL:" "$repo_url")

# Check if the file exists
if [ ! -f "$file" ]; then
    echo "Error: File '$file' does not exist."
    exit 1
fi

# Check if the file contains a line with the given substring
if grep -q "$substring" "$file"; then
    sed -i.bak "s/^$substring.*/$replacement/" "$file" && rm "$file".bak
    echo "$file" " updated with " "$replacement"
else
    echo "Error the repoURL field does not exist"
fi

if [ -z "$branch" ]; then
    # change the kustomizefile for argocd repo
    file="$repo_dir""/deployment/mesh-infra/argocd/projects/base/app.yaml"
    substring="targetRevision"
    replacement="targetRevision: $branch"

    # Check if the file contains a line with the given substring
    if grep -q "$substring" "$file"; then
        sed -i.bak "s/^$substring.*/$replacement/" "$file" && rm "$file".bak
    else
        echo "ArgoCD customisation file must have targetRevision field"
    fi
fi

kustomize build $(echo "$repo_dir""/deployment/mesh-infra/argocd") | kubectl apply -f -

#try twice
kustomize build $(echo "$repo_dir""/deployment/mesh-infra/argocd") | kubectl apply -f -

kubectl get pod -A

node.config -microk8s basicnode-secrets

echo "ArgoCD installed"

echo "should be done"
