# Services

We operate a range of services on top of the Kubernetes cluster.  


## iRods

To use Kubernetes cluster with Sanger data storage systems, we need to create a cluster secret which can be used by iRods. In the `sanger/irods-secret.yml` substitute the `IPW` and `IUN` with your username and password in base64 encoding. To encode please use:

```
echo -n IRODS_USER_NAME | base64
```

To create a secret:
```
kubectl create -f irods-secret.yml
```

After that you can start using our iRods image (`quay.io/cellgeni/irods`) without needing to provide your credentials.

## Nextflow

To be able to run Nextflow on Kubernetes we need to create a persistent volume claim (PVC) with `ReadWriteMany` access mode. The default OpenStack storage class (`cinder`) does not have this access mode. However, the GlusterFS storage (which we mounted to all of the nodes above) has it. 

### StorageClass

Since GlusterFS is mounted to all of the cluster nodes we can create a `hostpath` storage class for it. First, create the `glusterfs-sc.yaml` file with the following content:

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: glusterfs
provisioner: torchbox.com/hostpath
parameters:
  pvDir: /mnt/gluster
```

Now create the storage class:
```
kubectl create -f glusterfs-storage-class.yaml
```

### hostpath provisioner

`torchbox.com/hostpath` is not part of Kubernetes, therefore we need to deploy it first. Please use the `sanger/storage/glusterfs/deployment.yaml` file to do that:

```
kubectl create -f deployment.yaml
```

### PersistentVolumeClaim

Now we can create a PVC for Nextflow using the `sanger/storage/nf-pvc.yaml`:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nf-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 3000Gi
  storageClassName: "glusterfs"
```

Let's create the PVC:
```
kubectl create -f nf-pvc.yml
```

This will create a PVC folder in the mounted volume, e.g. `/mnt/gluster/pvc-0999129d-f188-11e8-adab-fa163e9c40bf`

### Nextflow RoleBinding

To allow Nextflow create pods in the `default` namespace you will need to run this script:
```
kubectl create clusterrolebinding nextflow --clusterrole=edit --serviceaccount=default:default -n default
```

More details can be found in this [issue](https://stackoverflow.com/questions/47973570/kubernetes-log-user-systemserviceaccountdefaultdefault-cannot-get-services).

__(TODO: in the future we would like to create a separate `nextflow` namespace specifically for Nextflow and give it permissions only in that namespace)__

### How to run Nextflow

If you run NF on K8s cluster from your computer nextflow will be using your local user name. For that to work you will need to create a user name folder (e.g. `user1`) in the PVC folder (e.g.
`/mnt/gluster/pvc-0999129d-f188-11e8-adab-fa163e9c40bf`). This requires sudo if you are user ubuntu.

Then create the `nf.config` file with the following content:
```
k8s {
  debug.yaml = true
}
```

then in the same folder run:
```
nextflow kuberun login -c nf.config -v nf-pvc
```

Nextflow will create its pod and a yaml file (`.nextflow.pod.yaml`), e.g.:

```
apiVersion: v1
kind: Pod
metadata:
  name: tiny-turing
  namespace: default
  labels: {app: nextflow, runName: tiny-turing}
spec:
  restartPolicy: Never
  containers:
  - name: tiny-turing
    image: nextflow/nextflow:0.31.1
    command: [/bin/bash, -c, source /etc/nextflow/init.sh; tail -f /dev/null]
    workingDir: /workspace/vk6
    env:
    - {name: NXF_WORK, value: /workspace/vk6/work}
    - {name: NXF_ASSETS, value: /workspace/projects}
    - {name: NXF_EXECUTOR, value: k8s}
    volumeMounts:
    - {name: vol-1, mountPath: /workspace}
    - {name: vol-2, mountPath: /etc/nextflow}
  volumes:
  - name: vol-1
    persistentVolumeClaim: {claimName: nf-pvc}
  - name: vol-2
    configMap: {name: nf-config-74272ba3}
```

Now you can reuse this file to manually create a NF pod with your own name and your own docker image. We have our NF docker image with the latest NF version and some additional software here: `quay.io/cellgeni/nf-login:18.10.1` (`18.10.1` is the latest version at the moment of writing)

To start a NF pod manually from the edited `.nextflow.pod.yaml` file, please run:

```
kubectl create -f .nextflow.pod.yaml
```

## JupyterHub

Once you have a Kubernetes cluster running it is very easy to deploy a JupyterHub server on it. We followed [these amazing instructions](https://zero-to-jupyterhub.readthedocs.io/en/stable/) and used the [Helm](https://helm.sh/) package manager which provides a ready to use Kubernetes version of JupyterHub.

Helm works the same way as `kubectl`, you install it on your local machine and interact with the cluster from it.

#### Helm version

When installing Helm make sure you have the same versions on the Kubernetes cluster and on you local machine. You can download a specific version of helm directly from their GitHub:

```
tar -zxvf helm-v2.9.1-darwin-amd64.tar.gz
mv darwin-amd64/helm /usr/local/bin/helm
```

#### Helm initialization

If helm is not installed on the cluster you can do 
```
kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
``` 
on your local machine and this will install the same version of helm on the cluster. If someone has already installed helm on the cluster, then run 
```
helm init --client-only
```

#### JupyterHub repository

Add `jupyterhub` repository to your helm:
```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
```

#### Start/upgrade JupyterHub on Kubernetes

To start a JupyterHub pod in the `jpt` name space for the first time run:

(download [jupyter-github-config.yaml](https://gitlab.internal.sanger.ac.uk/cellgeni/kubespray/blob/master/sanger/sites/jupyter-github-auth.yaml) for the Cellgeni specific setup and put it instead of `jupyter-config.yaml`)
```
# must be a default StorageClass to provision storage for new users
kubectl create -f sanger/storage/sc-rw-once.yaml
helm upgrade --install jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0 --values jupyter-config.yaml
```
Jupyter large
```
helm upgrade --install jptl jupyterhub/jupyterhub --namespace jptl --version 0.7.0 --values jupyter-large-config.yaml
```

Here the [jupyter-config.yaml](sanger/jupyter/jupyter-config.yaml) is used in which all of the Jupyter parameters are spefified.

If you update some parameters in the [jupyter-config.yaml](sanger/jupyter/jupyter-config.yaml), you will need to upgrade your JupyterHub deployment:
```
helm upgrade jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0-beta.2 --values jupyter-config.yaml
```

#### Tearing down JupyterHub

To tear down the hub, run

```
helm delete jpt --purge
kubectl delete namespace jpt
```

#### Jupyter notebook on a single instance

If you want to install Jupyter on a single instance, follow [these instructions](../sanger/jupyter/single-instance.md)


## Web

The deployment of web services that we host is described [here](web.md).

## Other services
#### Galaxy

```
# installing
helm install -n glx -f sanger/galaxy-config.yaml galaxy-helm-repo/galaxy-stable
# upgrading
helm upgrade -n glx -f sanger/galaxy-config.yaml galaxy-helm-repo/galaxy-stable
```

#### Kubernetes dashboard

Installation:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl apply -f sanger/users/dashboard-admin.yaml  # if only admins use the dashboard, otherwise create another rolebindings
```

Then run 
```
kubectl proxy
```
and open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/ in a web browser. Press "skip" on the login page.

## User access to Kubernetes cluster

#### Prerequisites:
kubectl >= 1.11

#### Setting up an account

1. Send a request for an account through the ticketing system.
2. Cellgeni team sends you three files: `ca.pem`, `user.crt`, `user.key`
Create a directory `$HOME/.kube/cellgeni` and place the files in this directory.
3. Run the following commands:
```
kubectl config set-cluster cellgeni \
  --embed-certs=true \
  --server=https://172.27.17.106:6443 \
  --certificate-authority=$HOME/.kube/cellgeni/ca.pem
kubectl config set-credentials user   --client-certificate=$HOME/.kube/cellgeni/user.crt  --client-key=$HOME/.kube/cellgeni/user.key
kubectl config set-context cellgeni --cluster=cellgeni --namespace=users --user=user
kubectl config use-context cellgeni
```
4. You can test access to the cluster with
```
kubectl --insecure-skip-tls-verify get pods
```

For now, you will need to enter `--insecure-skip-tls-verify` for every interaction with the cluster, until it is fixed you might want to create an alias. Add this to your `~/.bashrc` (Linux) or `~/.bash_profile` (Mac OS)
```
alias kubectl="kubectl --insecure-skip-tls-verify"
```
and then `source ~/.bash_profile`.

You can go back to your previous contexts with 
```
kubectl config use-context <context-name>
```
