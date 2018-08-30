#!/bin/bash

# https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-helm.html

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
helm upgrade --install jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0-beta.2 --values jupyter-config.yaml
kubectl --namespace=jpt get svc
