#!/usr/bin/env bash
# upgrades newest jupyter installation
helm upgrade jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0 --values jupyter-github-auth.yaml
