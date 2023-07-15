#!/bin/bash

# demo 4: upgrades

# note not using demo magic here really just keeping so the terminal looks consistent!
. demo-magic.sh
clear

## upgrading a virtual cluster is a lot less stressful than upgrading a "real" cluster
## there are no nodes to upgrade, only components that are running as pods!
## lets get right to it (note that this can be ran at the same time as 4b which will
## simply continually fetch nodes from the vcluster to show how minimal "downtime" is
## -- also note that that "downtime" is strictly for the apiserver, not for workloads!)
echo 'helm upgrade --install prod-a vcluster-k8s \
	--namespace prod-a \
	--repo https://charts.loft.sh \
	--version 0.15.3-beta.0 \
	--reuse-values \
	--set api.image=registry.k8s.io/kube-apiserver:v1.27.3 \
	--set controller.image=registry.k8s.io/kube-controller-manager:v1.27.3 \
	--set etcd.image=registry.k8s.io/etcd:3.5.9-0'

helm upgrade --install prod-a vcluster-k8s \
	--namespace prod-a \
	--repo https://charts.loft.sh \
	--version 0.15.3-beta.0 \
	--reuse-values \
	--set api.image=registry.k8s.io/kube-apiserver:v1.27.3 \
	--set controller.image=registry.k8s.io/kube-controller-manager:v1.27.3 \
	--set etcd.image=registry.k8s.io/etcd:3.5.9-0