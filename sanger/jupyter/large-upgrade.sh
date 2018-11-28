#!/usr/bin/env bash
# upgrades jupyter large
helm upgrade jptl jupyterhub/jupyterhub --namespace jptl --version 0.7.0-beta.2 --values jupyter-large-config.yaml