#!/bin/bash

# https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-helm.html

# use this on Linux
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
# or this on Mac OS
# brew install kubernetes-helm
kubectl --namespace kube-system create serviceaccount tillerkubectl create clusterrolebinding tiller 
kubectl create clusterrolebinding tiller 
helm init --service-account tiller
kubectl --namespace=kube-system patch deployment tiller-deploy --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'
kubectl -n kube-system patch deployment tiller-deploy -p '{"spec": {"template": {"spec": {"automountServiceAccountToken": true}}}}'