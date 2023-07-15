#!/bin/bash

# demo 4b: upgrades

. demo-magic.sh
clear

while :; do
    pei "KUBECONFIG=kubeconfigs/prod-a kubectl get pods -A -o wide"
    pei "kubectl get pods -n prod-a -o wide"
    sleep 1
done