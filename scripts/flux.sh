#!/usr/bin/env bash
set -e

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

# create vault namespace
kubectl create namespace vault

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    name: flux
  name: flux
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  labels:
    name: flux
  name: flux
rules:
  - apiGroups: ['*']
    resources: ['*']
    verbs: ['*']
  - nonResourceURLs: ['*']
    verbs: ['*']
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  labels:
    name: flux
  name: flux
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flux
subjects:
  - kind: ServiceAccount
    name: flux
    namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flux
spec:
  replicas: 1
  selector:
    matchLabels:
      name: flux
  strategy:
    type: Recreate
  template:
    metadata:
      annotations:
        prometheus.io.port: "3031" # tell prometheus to scrape /metrics endpoint's port.
      labels:
        name: flux
    spec:
      serviceAccountName: flux
      volumes:
      - name: git-key
        secret:
          secretName: flux-git-deploy
          defaultMode: 0400 # when mounted read-only, we won't be able to chmod

      - name: git-keygen
        emptyDir:
          medium: Memory

      containers:
      - name: flux
        image: weaveworks/flux:1.12.3
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
        ports:
        - containerPort: 3030 # informational
        volumeMounts:
        - name: git-key
          mountPath: /etc/fluxd/ssh # to match location given in image's /etc/ssh/config
          readOnly: true # this will be the case perforce in K8s >=1.10
        - name: git-keygen
          mountPath: /var/fluxd/keygen # to match location given in image's /etc/ssh/config

        args:
        - --memcached-hostname=memcached.default.svc.cluster.local
        - --memcached-service=
        - --ssh-keygen-dir=/var/fluxd/keygen
        - --git-url=git@github.com:primeroz/flux-bug-test-repo.git
        - --git-branch=master
        - --listen-metrics=:3031
        - --git-ci-skip
        - --git-path=test-cm-no-checksum
        - --git-label=dev-random-id
        - --git-poll-interval=1m
        - --sync-garbage-collection=true
---
apiVersion: v1
kind: Secret
metadata:
  name: flux-git-deploy
type: Opaque
---
# memcached deployment used by Flux to cache
# container image metadata.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memcached
spec:
  replicas: 1
  selector:
    matchLabels:
      name: memcached
  template:
    metadata:
      labels:
        name: memcached
    spec:
      containers:
      - name: memcached
        image: memcached:1.4.25
        imagePullPolicy: IfNotPresent
        args:
        - -m 128   # Maximum memory to use, in megabytes
        - -I 5m    # Maximum size for one item
        - -p 11211 # Default port
        ports:
        - name: clients
          containerPort: 11211
---
apiVersion: v1
kind: Service
metadata:
  name: memcached
spec:
  ports:
    - name: memcached
      port: 11211
  selector:
    name: memcached
EOF

