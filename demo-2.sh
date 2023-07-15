#!/bin/bash

# demo 2: admin things (security/quotas)

. demo-magic.sh
clear

## let's start with the least fun but maybe one of the more critical security options --
## running rootless! typically this will be a requirement driven from some security minded
## folk. this isn't all that existing from a vcluster perspective, but let's take a quick look
## at how we can configure this, and while we're there, we can see where we cranked up our
## replica counts for the core vcluster services...
## ok, so the easy/obvious part here -- replicas, not too exciting, but nice to see how simple
## it is!
## next up we've got our security context settings -- in this case we drop all capabilities,
## set non root user/group and disable privilege escalation, not too thrilling, but effective!
## do note that the api server *does need NET_BIND_SERVICE* capabilities added back in!
## while we're here we can also see something else interesting -- syncer flags. these are the flags
## that control how the "syncer" operates. in our case the only interesting one is that we sync
## the istio inject label, *but* on the topic of security the `enforce-pod-security-standard` flag
## can be passed here to as you'd imagine, in our case, we'll enforce the "baseline" standard.
pe "cat bootstrap/prod-a-values.yaml | yq .syncer"

## speaking of that pss -- lets try to violate it and see what happens...
## note that because this is configured in the syncer, and the sycner doesn't live *in* the vcluster
## users/tenants cannot modify this!
pe "cat manifests/badpod.yaml | yq"
pe "KUBECONFIG=kubeconfigs/prod-a kubectl apply -f manifests/badpod.yaml"

## because a vcluster lives in a single namespace applying quotas and network policies that
## apply to the entire cluster is a breeze! to start, lets see what kind of quota we've got
## configured
pe "kubectl describe quota prod-a-quota -n prod-a"

## lets take a look at this from the perspective of the vcluster...
## it shouldn't really be all that surprising that there are no quotas in the vcluster -- the quota
## we saw in the previous step actually lives in the *host cluster*
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get quota -A"

## so, what happens when we try to create some more pods?
pe "KUBECONFIG=kubeconfigs/prod-a kubectl create deployment willitwork --image=nginx --replicas=3 -n default"

## lets see if our pods are getting spun up...
pe "KUBECONFIG=kubeconfigs/prod-a kubectl get pods -n default"

## pending huh...
## well i happen to know we'll see an event from the syncer giving us some info -- so lets use this nasty
## one-liner to snag some pod output. if you didn't know this you could still get some good info by
## seeing that the pod(s) are pending and have N (probably 0) available replicas!
## the really neat thing about this is that the tenant has zero ability to delete this quota -- because
## they have no access to the host cluster -- so even a cluster admin in the vcluster cant "fix" this!
pe "KUBECONFIG=kubeconfigs/prod-a kubectl describe -n default pod $(KUBECONFIG=kubeconfigs/prod-a kubectl get pods -n default --no-headers | grep Pending | awk 'NR==1{print $1}')"


# TODO - jspolicy in both host and vcluster, show that if we are cluster admin wec an delete webhooks in
# the vcluster, but the host cluster will still prevent us from doing bad things!