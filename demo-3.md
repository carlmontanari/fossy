# Demo 3 -- Visibility


## As an Admin

http://grafana.loft.local:8080/

As a (real) cluster admin you of course want to have visibility into your cluster -- a common (the common!?) way to do this is to use the kube prometheus stack. We're not monitoring/visibility experts so we aren't going to get too crazy here, instead we're just going to do a very quick tour of some basic visibility aspects of living with vclusters!


### Monitoring the vcluster itself

One of the nice things about virtual clusters is that they really are just pods at the end of the day! Those pods are part of a deployment (or statefulset depending on your vcluster deployment), and they just run in your normal cluster like any other resource, and therefore can be monitored "like normal"!

You can start by checking out the "Namespace (Workloads)" dashboard in grafana -- this is an easy way to check on the deployments for the API server, the controller and the vcluster itself (these are all deployments). You can of course do normal grafana-y things and drill into the deployments down to pods and see all the metrics collected.

You can also flip over to statefulsets to check on the etcd instances -- again, not the most exciting thing in the world, but obviously this is crucial for a production style vcluster deployment -- staying on top of these workloads matters!


### Monitoring resources *in* the vcluster

Workloads *in* a vcluster are a little bit different -- because the vcluster syncs resources from "in" the vcluster into a single namespace in the host cluster (regardless of the namespace of the resource in the vcluster), checking out the "Namespaces (Pods)" dashboard is the best starting point (of the default dashboards!) for investigating the vcluster resources. Note that "workloads" (deployments/satefulsets) are *not* synced to the host cluster -- so we will only be seeing pods here!

Again, with the default graphs we'll be seeing all of the *translated* names of resources -- but, the sycner will have preserved the names, namespaces and some other data from the object "inside" the vcluster as annotations -- so with a tiny bit of work you could easily create a new dashboard specific for vcluster(s) that show the "real" names of resources!

Regardless of the naming silliness, even with the default dashboards we can easily see all the data we need to about the resources inside of the virtual cluster!


## As a Tenant

Running clusters in clusters presents some interesting questions that you may not have had before! Should you run a visibility/logging stack just once in the "host" cluster, or should each virtual cluster have its own stack as well? If they have their own stack, should they have visibility to all nodes or just the nodes that their virtual cluster runs in!?

Obviously there are no one size fits all answers here! In this demo environment we've installed a full kube-prometheus stack in our virtual cluster -- the idea here would be that the "tenant" of the virtual cluster may not even know that they are running in a virtual cluster! 

Note that as the admin/platform-team we've installed this for our tenant -- we've done some minor tweaks to ensure that they've got a full stack all their own and they are not accidentally grabbing metrics from the host cluster prometheus, this means that when they pop into Grafana (or obviously prometheus directly) they only see metrics for the nodes that their vcluster runs in!


### Gimme my own Grafana!

We've not got a ton going on *in* the virtual cluster so it may be most interesting to check out the actual kube-prometheus deployment bits. Of course from this perspective we have no name translation challenges with the default charts too so thats pretty neat! Also note that the only nodes that we have any visibility to are the ones that have been selected for the vcluster via the admins deployment!


