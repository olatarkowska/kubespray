#!/usr/bin/env bash
cd /Users/ak27/programming/cellgeni/kubespray/sanger/sites
git add jupyter-github-auth.yaml jupyter-large-config.yaml && git commit -m "Add new users" && git push
cd -