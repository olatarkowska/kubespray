Upgrading


```
helm upgrade jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0-beta.2 --values jupyter-config.yaml
```

Tearing down

helm delete jpt --purge
kubectl delete namespace jpt
