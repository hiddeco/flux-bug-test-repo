#!/usr/bin/env bash
set -e

command -v kind >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then 
  echo "You need to download KIND from https://github.com/kubernetes-sigs/kind/releases" 
  exit 1
fi
version=$(kind version)
if [ "x$version" != "xv0.3.0" ]; then
  echo "You need version 0.3.0 of Kind"
  exit 1
fi

K8S_VERSION="${K8S_VERSION:-v1.12.8@sha256:cc6e1a928a85c14b52e32ea97a198393fb68097f14c4d4c454a8a3bc1d8d486c}"
K8S_WORKERS="${K8S_WORKERS:-1}"

function start_kind() {
    cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
networking:
  apiServerAddress: 0.0.0.0
nodes:
- role: control-plane
  image: kindest/node:${K8S_VERSION}
EOF

for i in `seq 1 ${K8S_WORKERS}`;
do
    cat >> /tmp/kind-config.yaml <<EOF
- role: worker
  image: kindest/node:${K8S_VERSION}
EOF
done

    kind create cluster --config /tmp/kind-config.yaml

    #export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
    #kubectl cluster-info
    #kubectl get all --all-namespaces
}

function load_image() {                                                                 
  IMAGE=$1                                  
        kind load docker-image "$IMAGE"
}  

export KIND_K8S_VERSION="${K8S_VERSION}"
start_kind
load_image banzaicloud/vault-operator:watch-external-secrets-using-labels
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

#kubectl rollout status -n kube-system daemonset ip-masq-agent --timeout=180s
#kubectl rollout status -n kube-system daemonset kindnet --timeout=180s
kubectl rollout status -n kube-system daemonset kube-proxy --timeout=180s
kubectl rollout status -n kube-system deployment coredns --timeout=180s

echo "Kind Cluster is ready"
echo "  === "
echo "export KUBECONFIG=\"$(kind get kubeconfig-path --name=\"kind\")\""
kubectl cluster-info
kubectl get all --all-namespaces
