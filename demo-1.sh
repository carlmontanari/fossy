#!/bin/bash

# demo 1: basics

. demo-magic.sh
clear

## get nodes to show we are connected to our nice little multi-node k3s cluster
pe "kubectl get nodes"

## cool, lets take a high level look at what we've actually deployed
## some things we want to cover here
## 	 - the ha vcluster is all in a single namespace from the host cluster perspective!
##   - we've got our core "services" (minio, istio, velero in this case) installed in the *host cluster*
##   - we can see that we've got a sidecar running on our "hello" app (we dont actually use the mesh, but
##     we can show that this is at least part of our mesh! (and we *do* use the istio ingress))
pe "kubectl get pods -A"

## so, how do we get to the virtual cluster? via an ingress of course, just like anything else
## in kubernoodles! in our case we're using our istio and setting this up as a virtual service rather
## than a "traditional" ingress, but either way -- we are gge
pe "kubectl get virtualservices -n prod-a prod-a-ingress"

## now, the same thing -- but -- from the perspective the vcluster, this is what our user/tenant would see
##   - some important points:
##     - notice we only have the explicitly configured nodes available/visible!
##     - you could use this to bind a vcluster to a dedicated node pool just for the vcluster, a very cool way
##       to get as close to multiple "real" clusters without paying for extra control planes!
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get nodes"
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get namespaces"
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get pods -A"

## not only do we have a nice setup in the vcluster itself -- but even cooler is that we can share some of
## the "shared service" type things from our host cluster -- in this case we can see that we are using
## ingresses here in the vcluster despite not having an ingress controller actually depoyed in here!
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get ingresses -A"

## cooler still -- we've mentioned istio -- you didnt see any istio control plane things in the vcluster
## yet... if we take a look we can see that we've got some istio bits in here, for example this
## gateway for a demo app we're using...
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get gateways -n hello hello-gateway -o yaml | yq"

## and we can confirm that our app is working too...
pe "open -a firefox -g http://app.loft.local:8080"

## note the namespace and pod? "hello" and "hello-kubernetes-XYZ"? -- all our vcluster resources
## appear to be in namespaces from the tenant/user perspective, but actually live in a single
## namespace in the host cluster -- pretty cool!
pe "kubectl get po -n prod-a | grep hello"
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get po -n hello"

## the best part of all of this is that setting this whole thing up is pretty easy! the vcluster itself
## installed with helm, all very standard! we can take a quick look at the highlights of the values
## we used to get this setup how we want it. we'll cover some more of the values as we go along, but,
## for now, take a peak at the "sync" section -- here we can see we are syncing a specific set of nodes
## via the node selector (these align with the nodes we saw earlier of course), we've got ingress sync
## enabled as well -- this way we can use the "normal" istio ingress gateway without needing istio types
## (we do this for the grafana stuff we briefly saw earlier).
## the rest of this section is a very powerful feature called generic crd syncer -- this allows us to selectively
## sync crds to/from the host cluster/vcluster -- in this case, syncing the istio gateway and virtual service
## resources. this functionality can allow you to use any host cluster shared services with just a little
## bit of config tweaks required here!
pe "cat bootstrap/prod-a-values.yaml | yq .sync"
