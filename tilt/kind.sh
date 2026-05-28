#!/usr/bin/env bash
# set -euo pipefail

# kind-with-registry.sh
# Orchestrates Kind cluster creation with local registry and optional mirror configuration:
# 1. Install required tools (Tilt, Kind, kubectl, Helm)
# 2. Create local Docker registry
# 3. Configure container registry mirrors
# 4. Create Kind cluster with proper configuration
# 5. Deploy Flux and Sylva with Gitea integration

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

# ============================================================================
# Default values
# ============================================================================

DEFAULT_REG_NAME="kind-registry"
DEFAULT_REG_PORT="5001"
DEFAULT_EXTRA_CA_CERTS_FILE="${HOME}/chain_combined.crt"

# ============================================================================
# Helper functions
# ============================================================================

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN] $*"
}

# ============================================================================
# Registry mirror configuration
# ============================================================================

generate_hosts_yaml() {
    local registry_name=$1
    local registry_mirror_url=$2
    local registry_mirror_override_path=$3

    sudo mkdir -p "$(pwd)/certs.d/${registry_name}/"

    local file="$(pwd)/certs.d/${registry_name}/hosts.toml"

    sudo tee "${file}" > /dev/null <<EOF
server = "https://${registry_name}/"
[host."${registry_mirror_url}"]
  capabilities = ["pull","resolve"]
  override_path = ${registry_mirror_override_path}
  skip_verify = true
EOF
}

configure_registry_mirror() {
    local name=$1
    local display_name=$2
    local mirror_url=$3
    local override_path=$4
    local aliases=${5:-}

    if [ -n "${mirror_url}" ]; then
        log_info "Configuring mirror for ${display_name}..."
        generate_hosts_yaml "${name}" "${mirror_url}" "${override_path}"

        # Handle aliases (e.g., docker.io -> registry-1.docker.io)
        if [ -n "${aliases}" ]; then
            for alias in ${aliases}; do
                generate_hosts_yaml "${alias}" "${mirror_url}" "${override_path}"
            done
        fi
        log_success "${display_name} mirror configured"
    else
        log_info "No ${display_name} mirror provided, skipping"
    fi
}

# ============================================================================
# Tool installation functions
# ============================================================================

install_tilt() {
    if command -v tilt >/dev/null 2>&1; then
        log_info "Tilt is already installed"
        TILT_VERSION=$(tilt version)
        log_info "tilt version: ${TILT_VERSION}"
        return 0
    fi

    log_info "Installing Tilt..."
    if curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash; then
        log_success "Tilt installed successfully"
    else
        log_error "Failed to install Tilt"
        return 1
    fi
    TILT_VERSION=$(tilt version)
    log_info "tilt version: ${TILT_VERSION}"
}

install_kind() {
    if command -v kind >/dev/null 2>&1; then
        log_info "Kind is already installed"
        KIND_VERSION=$(/usr/local/bin/kind version)
        log_info "kind version: ${KIND_VERSION}"
        return 0
    fi

    log_info "Installing Kind..."
    if sudo wget -qO /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64 && \
        sudo chmod +x /usr/local/bin/kind; then
        log_success "Kind installed successfully"
    else
        log_error "Failed to install Kind"
        return 1
    fi
    KIND_VERSION=$(/usr/local/bin/kind version)
    log_info "kind version: ${KIND_VERSION}"

}

install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        log_info "kubectl is already installed"
        KUBECTL_VERSION=$(/usr/local/bin/kubectl version 2>/dev/null)
        log_info "kubectl version: ${KUBECTL_VERSION}"
        return 0
    fi

    log_info "Installing kubectl..."
    local kubectl_version arch
    kubectl_version="v1.35.0"
    arch="$(uname -m)"; [[ "$arch" == "x86_64" ]] && arch="amd64"; [[ "$arch" == "aarch64" ]] && arch="arm64"
    log_info "Installing kubectl... fetching version ${kubectl_version} for architecture ${arch}"
    if sudo curl -fsSL "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${arch}/kubectl" -o /usr/local/bin/kubectl && \
        sudo chmod +x /usr/local/bin/kubectl; then
        log_success "kubectl installed successfully"
    else
        log_error "Failed to install kubectl"
        return 1
    fi

    KUBECTL_VERSION=$(/usr/local/bin/kubectl version 2>/dev/null)
    log_info "kubectl version: ${KUBECTL_VERSION}"

}

install_helm() {
    if command -v helm >/dev/null 2>&1; then
        log_info "Helm is already installed"
        HELM_VERSION=$(helm version)
        log_info "helm version: ${HELM_VERSION}"
        return 0
    fi

    log_info "Installing Helm..."
    if curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash; then
        log_success "Helm installed successfully"
    else
        log_error "Failed to install Helm"
        return 1
    fi
    HELM_VERSION=$(helm version)
    log_info "helm version: ${HELM_VERSION}"

}

install_envsubst() {
  if command -v envsubst >/dev/null 2>&1; then
    log_info "envsubst is already installed"
    return 0
  fi

  log_info "Installing envsubst (gettext-base)..."
  sudo install -m 0755 ./envsubst /usr/local/bin/envsubst
  log_success "envsubst installed successfully"
}

install_required_tools() {
    log_info "Checking and installing required tools..."
    echo ""

    install_tilt
    install_kind
    install_kubectl
    install_helm
    install_envsubst

    echo ""
    log_success "All required tools are available"
}

# ============================================================================
# Docker registry functions
# ============================================================================

create_local_registry() {
    local reg_name=$1
    local reg_port=$2

    log_info "Setting up local Docker registry '${reg_name}' on port ${reg_port}..."

    if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" = 'true' ]; then
        log_info "Registry '${reg_name}' is already running"
        return 0
    fi

    log_info "Creating registry container..."
    if docker run -d --restart=always -p "127.0.0.1:${reg_port}:5000" \
        --network bridge --name "${reg_name}" registry:2; then
        log_success "Registry '${reg_name}' created successfully"
    else
        log_error "Failed to create registry container"
        return 1
    fi
}

configure_local_registry() {
    local reg_name=$1
    local reg_port=$2
    local registry_dir=$3

    local registry_dir_local="${registry_dir}/localhost:${reg_port}"
    mkdir -p "${registry_dir_local}"

    cat <<EOF > "${registry_dir_local}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF

    log_success "Local registry configuration created"
}

connect_registry_to_kind() {
    local reg_name=$1

    if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}" 2>/dev/null)" = 'null' ]; then
        log_info "Connecting registry to Kind network..."
        if docker network connect "kind" "${reg_name}"; then
            log_success "Registry connected to Kind network"
        else
            log_error "Failed to connect registry to Kind network"
            return 1
        fi
    else
        log_info "Registry already connected to Kind network"
    fi
}

create_registry_configmap() {
    local reg_port=$1

    log_info "Creating ConfigMap for local registry hosting..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
    log_success "Registry ConfigMap created"
}

# ============================================================================
# Kind cluster functions
# ============================================================================

create_kind_cluster() {
    local registry_dir=$1

    if kind get clusters 2>/dev/null | grep -q '^kind$'; then
        log_info "Kind cluster already exists, skipping creation"
        return 0
    fi
    GITLAB_CI_KIND_CONFIG=""
    if [ "$GITLAB_CI" = "true" ]; then
    GITLAB_CI_KIND_CONFIG=$(cat <<EOF
networking:
  apiServerAddress: 0.0.0.0
kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
        - "docker"
EOF
)
    fi


    log_info "Creating Kind cluster..."
    cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
${GITLAB_CI_KIND_CONFIG}

nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
    - hostPath: "${registry_dir}"
      containerPath: /etc/containerd/certs.d
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    imageGCHighThresholdPercent: 80
    imageGCLowThresholdPercent: 60
    imageMinimumGCAge: 1m
    imageMaximumGCAge: 0s
    serializeImagePulls: false
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
EOF

    if [ $? -eq 0 ]; then
        log_success "Kind cluster created successfully"
    else
        log_error "Failed to create Kind cluster"
        return 1
    fi

    if [ "$GITLAB_CI" = "true" ]; then
    # Modify kubeconfig to replace localhost/
    sed -i.bak -E -e "s/localhost|0\.0\.0\.0/docker/g" "$HOME/.kube/config"
    fi

}

# ============================================================================
# Proxy configuration
# ============================================================================

configure_proxy_settings() {
    log_info "Configuring proxy settings..."

    # Check for http_proxy (lowercase or uppercase)
    local http_proxy_value="${http_proxy:-${HTTP_PROXY:-}}"
    if [ -n "${http_proxy_value}" ]; then
        log_info "Found http_proxy: ${http_proxy_value}"
        export http_proxy="${http_proxy_value}"
        export HTTP_PROXY="${http_proxy_value}"
        log_success "http_proxy/HTTP_PROXY exported"
    else
        log_info "No http_proxy set"
    fi

    # Check for https_proxy (lowercase or uppercase)
    local https_proxy_value="${https_proxy:-${HTTPS_PROXY:-}}"
    if [ -n "${https_proxy_value}" ]; then
        log_info "Found https_proxy: ${https_proxy_value}"
        export https_proxy="${https_proxy_value}"
        export HTTPS_PROXY="${https_proxy_value}"
        log_success "https_proxy/HTTPS_PROXY exported"
    else
        log_info "No https_proxy set"
    fi

    # Only configure no_proxy if http_proxy or https_proxy is set
    if [ -n "${http_proxy_value}" ] || [ -n "${https_proxy_value}" ]; then
        # Domains to add to no_proxy
        local no_proxy_additions="localhost,${DEFAULT_REG_NAME},.local,.sylva.local"

        # Check for no_proxy (lowercase or uppercase) and add required domains
        local no_proxy_value="${no_proxy:-${NO_PROXY:-}}"
        if [ -n "${no_proxy_value}" ]; then
            log_info "Found existing no_proxy: ${no_proxy_value}"
            # Append our additions if not already present
            for domain in ${no_proxy_additions//,/ }; do
                if [[ ! ",${no_proxy_value}," == *",${domain},"* ]]; then
                    no_proxy_value="${no_proxy_value},${domain}"
                fi
            done
        else
            no_proxy_value="${no_proxy_additions}"
        fi

        export no_proxy="${no_proxy_value}"
        export NO_PROXY="${no_proxy_value}"
        log_success "no_proxy/NO_PROXY exported: ${no_proxy_value}"
    else
        log_info "No proxy configured, skipping no_proxy configuration"
    fi

    echo ""
}

# ============================================================================
# Extra CA certificates support
# ============================================================================

setup_extra_ca_certs() {
    local ca_file="${EXTRA_CA_CERTS_FILE:-${DEFAULT_EXTRA_CA_CERTS_FILE}}"

    if [ -f "${ca_file}" ]; then
        log_info "Found extra CA certificates file: ${ca_file}"
        EXTRA_CA_CERTS=$(base64 -w 0 "${ca_file}")
        export EXTRA_CA_CERTS
        export EXTRA_CA_CERTS_FILE="${ca_file}"
        log_success "Extra CA certificates loaded and exported"
        return 0
    else
        log_info "No extra CA certificates file found at ${ca_file}"
        log_info "Set EXTRA_CA_CERTS_FILE to specify a custom path"
        export EXTRA_CA_CERTS=""
        return 0
    fi
}

# ============================================================================
# Pod status check function
# ============================================================================

check_pods_status() {
    local namespace=$1
    local label_selector=${2:-}

    if [ -z "${namespace}" ]; then
        log_error "Namespace argument is required"
        return 1
    fi

    log_info "Waiting for namespace '${namespace}'..."
    until kubectl get namespace "${namespace}" &>/dev/null; do
        sleep 2
    done
    log_success "Namespace '${namespace}' found"

    # Build kubectl command
    local kubectl_cmd="kubectl get pods -n ${namespace} --no-headers"
    if [ -n "${label_selector}" ]; then
        kubectl_cmd="${kubectl_cmd} -l ${label_selector}"
        log_info "Using label selector: ${label_selector}"
    fi

    log_info "Checking pod status in namespace '${namespace}'..."
    while true; do
        local pod_info
        pod_info=$(eval "${kubectl_cmd}" 2>/dev/null | awk '{print $2 ":" $3}')

        if [ -z "${pod_info}" ]; then
            log_info "No pods found, waiting..."
        else
            local all_ready=true
            while IFS=':' read -r ready_status pod_status; do
                [ -z "${ready_status}" ] && continue

                if [ "${pod_status}" = "Completed" ] || [ "${pod_status}" = "Succeeded" ]; then
                    continue
                elif [ "${pod_status}" = "Running" ]; then
                    local ready_count total_count
                    ready_count=$(echo "${ready_status}" | cut -d'/' -f1)
                    total_count=$(echo "${ready_status}" | cut -d'/' -f2)

                    if [ "${ready_count}" = "${total_count}" ] && [ "${ready_count}" != "0" ]; then
                        continue
                    else
                        all_ready=false
                        break
                    fi
                else
                    all_ready=false
                    break
                fi
            done <<< "${pod_info}"

            if ${all_ready}; then
                log_success "All pods in '${namespace}' are ready"
                break
            fi
        fi

        sleep 5
    done
}

# ============================================================================
# User input collection
# ============================================================================

collect_mirror_configuration() {

    read -e -p "Enter Docker Hub mirror URL: " -i "${DOCKER_MIRROR_URL:-}" DOCKER_MIRROR_URL
    read -e -p "Override path for Docker Hub (true/false): " -i "${DOCKER_OVERRIDE_PATH:-}" DOCKER_OVERRIDE_PATH

    read -e -p "Enter GHCR mirror URL: " -i "${GHCR_MIRROR_URL:-}" GHCR_MIRROR_URL
    read -e -p "Override path for GHCR (true/false): " -i "${GHCR_OVERRIDE_PATH:-}" GHCR_OVERRIDE_PATH

    read -e -p "Enter registry.k8s.io mirror URL: " -i "${REGISTRY_K8S_MIRROR_URL:-}" REGISTRY_K8S_MIRROR_URL
    read -e -p "Override path for registry.k8s.io (true/false): " -i "${REGISTRY_K8S_OVERRIDE_PATH:-}" REGISTRY_K8S_OVERRIDE_PATH

    read -e -p "Enter quay.io mirror URL: " -i "${QUAY_MIRROR_URL:-}" QUAY_MIRROR_URL
    read -e -p "Override path for quay.io (true/false): " -i "${QUAY_OVERRIDE_PATH:-}" QUAY_OVERRIDE_PATH

    read -e -p "Enter oci.external-secrets.io mirror URL: " -i "${OCI_EXTERNAL_SECRETS_IO_MIRROR_URL:-}" OCI_EXTERNAL_SECRETS_IO_MIRROR_URL
    read -e -p "Override path for oci.external-secrets.io (true/false): " -i "${OCI_EXTERNAL_SECRETS_IO_OVERRIDE_PATH:-}" OCI_EXTERNAL_SECRETS_IO_OVERRIDE_PATH

    read -e -p "Enter registry.gitlab.com mirror URL: " -i "${GITLAB_COM_MIRROR_URL:-}" GITLAB_COM_MIRROR_URL
    read -e -p "Override path for registry.gitlab.com (true/false): " -i "${GITLAB_COM_OVERRIDE_PATH:-}" GITLAB_COM_OVERRIDE_PATH

    read -e -p "Enter reg.kyverno.io mirror URL: " -i "${REG_KYVERNO_IO_MIRROR_URL:-}" REG_KYVERNO_IO_MIRROR_URL
    read -e -p "Override path for reg.kyverno.io (true/false): " -i "${REG_KYVERNO_IO_OVERRIDE_PATH:-}" REG_KYVERNO_IO_OVERRIDE_PATH

    read -e -p "Enter gcr.io mirror URL: " -i "${GCR_IO_MIRROR_URL:-}" GCR_IO_MIRROR_URL
    read -e -p "Override path for gcr.io (true/false): " -i "${GCR_IO_OVERRIDE_PATH:-}" GCR_IO_OVERRIDE_PATH

    read -e -p "Enter xpkg.crossplane.io mirror URL: " -i "${XPKG_CROSSPLANE_IO_MIRROR_URL:-}" XPKG_CROSSPLANE_IO_MIRROR_URL
    read -e -p "Override path for xpkg.crossplane.io (true/false): " -i "${XPKG_CROSSPLANE_IO_OVERRIDE_PATH:-}" XPKG_CROSSPLANE_IO_OVERRIDE_PATH

    echo ""
}

collect_registry_configuration() {


    read -p "Enter local registry name (default: '${DEFAULT_REG_NAME}'): " reg_name
    REG_NAME=${reg_name:-${DEFAULT_REG_NAME}}

    read -p "Enter local registry port (default: '${DEFAULT_REG_PORT}'): " reg_port
    REG_PORT=${reg_port:-${DEFAULT_REG_PORT}}

    echo ""
}

collect_bundle_configuration() {

    read -e -p "Is GitLab CI? (true/false): " -i "${GITLAB_CI:-false}" GITLAB_CI
    export GITLAB_CI

    # Determine cluster IP based on environment
    if [ "${GITLAB_CI}" = "true" ]; then
        # In GitLab CI, get IP from docker host
        CLUSTER_IP=$(getent hosts docker | awk '{print $1}')
        if [ -z "${CLUSTER_IP}" ]; then
            log_warn "Could not determine Docker host IP, using empty value"
            CLUSTER_IP=""
        fi
    else
        # On VM, use machine's first IP address
        CLUSTER_IP=$(hostname -I | awk '{print $1}')
    fi
    export CLUSTER_IP
    log_info "Cluster IP: ${CLUSTER_IP:-not set}"

    echo ""
}

# ============================================================================
# /etc/hosts configuration
# ============================================================================

# Default hostnames to add to /etc/hosts
DEFAULT_LOCAL_HOSTNAMES=(
    "frontend.local"
)

configure_etc_hosts() {
    local ip=$1
    shift
    local hostnames=("$@")

    if [ -z "${ip}" ]; then
        log_warn "No IP address provided, skipping /etc/hosts configuration"
        return 0
    fi

    if [ ${#hostnames[@]} -eq 0 ]; then
        hostnames=("${DEFAULT_LOCAL_HOSTNAMES[@]}")
    fi

    log_info "Configuring /etc/hosts with IP: ${ip}"
    log_info "Hostnames: ${hostnames[*]}"

    for hostname in "${hostnames[@]}"; do
        # Check if entry already exists
        if grep -q "${hostname}" /etc/hosts 2>/dev/null; then
            # Update existing entry
            log_info "Updating existing entry for ${hostname}"
            sudo sed -i "/[[:space:]]${hostname}\$/d" /etc/hosts
            sudo sed -i "/${hostname}[[:space:]]/d" /etc/hosts
        fi

        # Add new entry
        echo "${ip} ${hostname}" | sudo tee -a /etc/hosts > /dev/null
        log_success "Added ${hostname} -> ${ip}"
    done

    log_success "/etc/hosts configured successfully"
}

# ============================================================================
# Configure all registry mirrors
# ============================================================================

configure_all_mirrors() {
    local registry_dir=$1

    log_info "Configuring registry mirrors..."
    mkdir -p "${registry_dir}"
    echo ""

    configure_registry_mirror "docker.io" "Docker Hub" \
        "${DOCKER_MIRROR_URL:-}" "${DOCKER_OVERRIDE_PATH:-}" "registry-1.docker.io"

    configure_registry_mirror "quay.io" "Quay.io" \
        "${QUAY_MIRROR_URL:-}" "${QUAY_OVERRIDE_PATH:-}"

    configure_registry_mirror "ghcr.io" "GHCR" \
        "${GHCR_MIRROR_URL:-}" "${GHCR_OVERRIDE_PATH:-}"

    configure_registry_mirror "registry.k8s.io" "registry.k8s.io" \
        "${REGISTRY_K8S_MIRROR_URL:-}" "${REGISTRY_K8S_OVERRIDE_PATH:-}"

    configure_registry_mirror "oci.external-secrets.io" "oci.external-secrets.io" \
        "${OCI_EXTERNAL_SECRETS_IO_MIRROR_URL:-}" "${OCI_EXTERNAL_SECRETS_IO_OVERRIDE_PATH:-}"

    configure_registry_mirror "registry.gitlab.com" "registry.gitlab.com" \
        "${GITLAB_COM_MIRROR_URL:-}" "${GITLAB_COM_OVERRIDE_PATH:-}"

    configure_registry_mirror "reg.kyverno.io" "reg.kyverno.io" \
        "${REG_KYVERNO_IO_MIRROR_URL:-}" "${REG_KYVERNO_IO_OVERRIDE_PATH:-}"

    configure_registry_mirror "gcr.io" "gcr.io" \
        "${GCR_IO_MIRROR_URL:-}" "${GCR_IO_OVERRIDE_PATH:-}"

    configure_registry_mirror "xpkg.crossplane.io" "xpkg.crossplane.io" \
        "${XPKG_CROSSPLANE_IO_MIRROR_URL:-}" "${XPKG_CROSSPLANE_IO_OVERRIDE_PATH:-}"

    echo ""
    log_success "Registry mirrors configured"
}

# ============================================================================
# Main workflow
# ============================================================================

main() {
    # Phase 1: Collect user input

    collect_mirror_configuration
    collect_registry_configuration
    collect_bundle_configuration

    log_info "Phase 1: configuration Collected"
    echo ""

    # Phase 2: Install required tools
    log_info "Phase 2: Installing required tools"
    install_required_tools
    echo ""

    # Phase 3: Configure proxy settings
    log_info "Phase 3: Configuring proxy settings"
    configure_proxy_settings
    echo ""

    # Phase 4: Setup extra CA certificates
    log_info "Phase 4: Setting up extra CA certificates"
    setup_extra_ca_certs
    echo ""

    # Phase 5: Create local registry
    log_info "Phase 5: Setting up local Docker registry"
    create_local_registry "${REG_NAME}" "${REG_PORT}"
    echo ""

    # Phase 6: Configure registry mirrors
    log_info "Phase 6: Configuring registry mirrors"
    REGISTRY_DIR="$(pwd)/certs.d/"
    configure_all_mirrors "${REGISTRY_DIR}"
    configure_local_registry "${REG_NAME}" "${REG_PORT}" "${REGISTRY_DIR}"
    echo ""

    # Phase 7: Create Kind cluster
    log_info "Phase 7: Creating Kind cluster"
    create_kind_cluster "${REGISTRY_DIR}"
    echo ""

    # Phase 8: Connect registry and configure cluster
    log_info "Phase 8: Connecting registry and configuring cluster"
    connect_registry_to_kind "${REG_NAME}"
    create_registry_configmap "${REG_PORT}"
    echo ""

    # Phase 9: Configure /etc/hosts
    log_info "Phase 9: Configuring /etc/hosts"
    configure_etc_hosts "${CLUSTER_IP}" "${DEFAULT_LOCAL_HOSTNAMES[@]}"
    echo ""

   
}

# Run main workflow
main "$@"
