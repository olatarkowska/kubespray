#!/usr/bin/env bash
# upgrades jupyter large
kubectl config use-context large-cellgeni
ssh -i ~/.ssh/farm4-head1-id_rsa -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -l ubuntu -Nf -L 16700:10.0.3.15:6443 172.27.18.144
helm upgrade jptl jupyterhub/jupyterhub --namespace jptl --version 0.7.0 --values jupyter-large-config.yaml
# helm upgrade --install jptl jupyterhub/jupyterhub --namespace jptl --version 0.7.0 --values jupyter-large-config.yaml