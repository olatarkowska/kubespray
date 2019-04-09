#!/usr/bin/env bash
# installs newest jupyter installation
helm upgrade --install jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0 --values jupyter-github-auth.yaml
