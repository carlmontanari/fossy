#!/bin/bash

set -euo pipefail

scriptDir=$(dirname -- "$( readlink -f -- "$0"; )";)

fetchKubeconfig() {
	namespace=$1
	name=$2
	outFile=$3
	kubeConfig=${4:-"${HOME}/.kube/config"}

    while ! KUBECONFIG=$kubeConfig kubectl get secret -n $namespace $2 ; do
    	echo "waiting for vcluster secret..."
    	sleep 10
	done

	KUBECONFIG=$kubeConfig kubectl get secret -n $namespace $2 -o jsonpath='{.data.config}' | \
    	base64 -d >	$outFile
}

checkBins() {
	if ! command -v kubectl &> /dev/null
	then
	    echo "kubectl could not be found, byeoooo!"
	    exit
	fi

	if ! command -v k3d &> /dev/null
	then
	    echo "k3d could not be found, byeoooo!"
	    exit
	fi

	if ! command -v vcluster &> /dev/null
	then
	    echo "vcluster could not be found, byeoooo!"
	    exit
	fi

	if ! command -v helm &> /dev/null
	then
	    echo "helm could not be found, byeoooo!"
	    exit
	fi

	if ! command -v velero &> /dev/null
	then
	    echo "velero could not be found, byeoooo!"
	    exit
	fi
}

checkHosts() {
	hostsContent=$(cat /etc/hosts)

	failed=false

	if ! grep -E -q '127\.0\.0\.1\s+prod-a.loft.local' <<< "$hostsContent"
	then
		echo "missing host entry for prod-a.loft.local"
		failed=true
	fi

	if ! grep -E -q '127\.0\.0\.1\s+app.loft.local' <<< "$hostsContent"
	then
		echo "missing host entry for app.loft.local"
		failed=true
	fi

	if ! grep -E -q '127\.0\.0\.1\s+grafana.loft.local' <<< "$hostsContent"
	then
		echo "missing host entry for grafana.loft.local"
		failed=true
	fi

	if ! grep -E -q '127\.0\.0\.1\s+prod-a.grafana.loft.local' <<< "$hostsContent"
	then
		echo "missing host entry for prod-a.grafana.loft.local"
		failed=true
	fi

	if $failed
	then
		echo "missing one or more host entries"
		echo "to run this demo you'll need entries in /etc/hosts that look like:"
		echo ""
		echo "127.0.0.1 prod-a.loft.local"
		echo "127.0.0.1 app.loft.local"
		echo "127.0.0.1 grafana.loft.local"
		echo "127.0.0.1 prod-a.grafana.loft.local"
		echo ""
		exit 1
	fi
}

startK3s() {
	echo "starting k3s cluster..."

	k3d cluster create local --servers 5 \
		--k3s-arg '--disable=traefik@server:*' \
		-p 8080:80@loadbalancer -p 8443:443@loadbalancer \
		--wait

	# let our vcluster run on 3 of our 5 nodes for funsies
	kubectl label nodes k3d-local-server-2 vclusterNodePool=prod-a
	kubectl label nodes k3d-local-server-3 vclusterNodePool=prod-a
	kubectl label nodes k3d-local-server-4 vclusterNodePool=prod-a

	echo "k3s cluster started!"
}


installMinio() {
	echo "getting minio setup..."

	helm upgrade --install minio \
		--namespace minio --create-namespace \
		--set auth.rootUser=admin \
		--set auth.rootPassword=password \
		--set defaultBuckets="velero" \
		oci://registry-1.docker.io/bitnamicharts/minio

	echo "minio setup!"
}

installVelero() {
	echo "installing velero..."

	# after creating a user in minio this worked, so just need to bootstrap taht w/ values
	# or lets try it w/ just admin/password from the root user?
	velero install \
		--use-node-agent \
		--namespace velero \
	    --provider aws \
	    --plugins velero/velero-plugin-for-aws:v1.2.1 \
	    --bucket velero \
	    --secret-file ./bootstrap/minio-secrets \
	    --use-volume-snapshots=false \
	    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.minio:9000

	echo "velero a-ok!"
}


installIstio() {
	echo "installing istio..."

	helm repo add istio https://istio-release.storage.googleapis.com/charts
	helm repo update

	helm upgrade --install istio-base istio/base -n istio-system --create-namespace
	helm upgrade --install istiod istio/istiod -n istio-system
	helm upgrade --install istio-ingressgateway istio/gateway -n istio-system

	kubectl apply -f manifests/ingress-class.yaml

	echo "istio all set!"
}

installKubePromStack() {
	echo "installing kube-prometheus-stack..."

	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

	helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
		--version 47.1.0 \
		--namespace kube-prometheus --create-namespace \
		--set prometheus.scrapeInterval="3s" \
		--set prometheus.evaluationInterval="5s" \
		--set grafana.ingress.enabled=true \
		--set grafana.ingress.ingressClassName=istio \
		--set grafana.ingress.hosts="{grafana.loft.local}" \
		--set grafana.adminPassword=password \
		--set alertmanager.enabled=false

	echo "kube-prometheus-stack lookin good!"
}

installProdHAVClusters() {
	echo "installing prod-a ha vcluster..."

	kubectl create namespace prod-a || true
	kubectl label namespace prod-a istio-injection=enabled
	kubectl apply -f manifests/prod-a-quota.yaml

	helm upgrade --install prod-a vcluster-k8s \
		--namespace prod-a \
		--repo https://charts.loft.sh \
		--version 0.15.3-beta.0 \
		--values bootstrap/prod-a-values.yaml

	kubectl patch daemonset prod-a-hostpath-mapper -n prod-a --patch '{"spec": {"template": {"metadata": {"labels": {"sidecar.istio.io/inject": "false"}}}}}'
	kubectl patch daemonset prod-a-hostpath-mapper -n prod-a --patch '{"spec": {"template": {"spec": {"nodeSelector": {"vclusterNodePool": "prod-a"}}}}}'

	fetchKubeconfig prod-a vc-prod-a $scriptDir/kubeconfigs/prod-a

	kubectl apply -f manifests/prod-a-gateway.yaml

	KUBECONFIG=kubeconfigs/prod-a kubectl apply -f manifests/hello-kubernetes-app-prod-a.yaml

	echo "prod-a ha vcluster ready to roll!"
}

checkBins
checkHosts
rm kubeconfigs/* || true
startK3s
installMinio
installVelero
installIstio
installKubePromStack
installProdHAVClusters
