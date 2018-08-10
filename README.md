![Kubernetes Logo](https://raw.githubusercontent.com/kubernetes-incubator/kubespray/master/docs/img/kubernetes-logo.png)

Kubernetes Cluster on Sanger Institute OpenStack cloud
======================================================

## Prerequisites

You will need a Sanger OpenStack account. Consult the [wiki](https://ssg-confluence.internal.sanger.ac.uk/display/OPENSTACK/OpenStack) for information about getting an account and getting started.

If you already have an OpenStack account and forgot your password you can find it by logging in to [Cloudforms](https://cloudforms.internal.sanger.ac.uk/) with your Sanger credentials and going to Services/Catalogs/Reset OpenStack Password. Click the `Order` button and then copy your previous password and click `Cancel`. This password will also be needed in one of the next steps.

## High-level overview of the process

To setup a Kubernetes cluster we will use Terraform and Ansible. Terraform creates instances in OpenStack, along with networks and volumes and all the other fiddly bits required for the Kubernetes cluster. Ansible provisions all the necessary software to those instances.

Both Terraform and Ansible are run from a _deployment machine_ (see below).

All of the software have been nicely packaged into [kubespray](https://github.com/kubernetes-incubator/kubespray) GitHub repository. Here we are using version 2.5.0 of the kubespray, which was obtained by forking the original repository and resetting the head of the repository to the commit before the release of version 2.5.0:
```
git reset --hard 02cd541
git push -f origin master
```

All other changes were introduced by us with an enormous help of Helen Cousins (@HelenCousins), Theo Barber-Bany (@theobarberbany), Stijn van Dongen (@micans) and Anton Khodak (@anton-khodak). 

### Deployment machine

* Download the OpenStack RC File (Identity API v3) and OpenStack RC File (Identity API v2) from [Horizon dashboard](https://zeta.internal.sanger.ac.uk) by going to `Project/Api Access`. This is your credentials for accessing the OpenStack command line interface.

For deployment please use `farm4-head1` node of the Sanger farm. It already has all of the required cloud command line interfaces installed for you.

* Copy your OpenStack RC Files to the farm node:

```
scp YOUR_OPENRC_V2.sh YOUR_USER_NAME@farm4-head1:~
scp YOUR_OPENRC_V3.sh YOUR_USER_NAME@farm4-head1:~
```
Use you Sanger credentials to authenticate.

* Login to the farm node:

```
ssh YOUR_USER_NAME@farm4-head1
```
Use you Sanger credentials to authenticate.

* Substitute the following lines in the YOUR_OPENRC_V3.sh file:

```
echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT
```

with the just the following line:

```
export OS_PASSWORD=YOUR_OPENSTACK_PASSWORD
```
(please paste the actual password)

* Substitute `export OS_PROJECT_ID=...` in the YOUR_OPENRC_V3.sh file with the `export OS_TENANT_ID=...` which you can find in the YOUR_OPENRC_V2.sh file.

* Delete `unset OS_TENANT_ID` from the YOUR_OPENRC_V3.sh file.

* Put the sourcing of the YOUR_OPENRC_V3.sh into your `.bashrc`.

* If you don't have an ssh key in your `~/.ssh` folder you will need to generate one and add it to your ssh agent:
```
ssh-keygen -t rsa
```
(follow the instructions)

* Run the following commands which will install all the prerequisites for `kubespray` and enter the `kubspray` directory:

```
git clone https://github.com/cellgeni/kubespray.git
cd kubespray
```

* We have prepared Terraform and Ansible installation for you in a conda environment. To activate the environment please run:
```
source /nfs/cellgeni/.cellgenirc
source activate k8s2.5.0
```

## Terraforming

Terraform creates infrastructure from a simple text configuration file. Follow this instructions on the terraform configuration file/variables: https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#cluster-variables

We have preconfigured our development/staging/production clusters, they are in `inventory/$ENVIRONMENT` folders.

You can either reuse our settings or create your own folder in the `invetory` folder with your own cluster settings.

The next step is to create you cloud infrastructure for kubernetes using Terraform. Follow this instructions for terraforming: https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#initialization

Note that there was a pull request created by us which was not merged to the 2.5.0 release of the kubespray (https://github.com/kubernetes-incubator/kubespray/pull/2681). Therefore we incorporated these changes manually in this repository.

### Sanger-specific variables
Most of the variables in this file can be adjusted for your own needs. However, there are a few of them which represent Sanger OpenStack settings:
```
dns_nameservers=["172.18.255.1"]
floatingip_pool="public"
external_net="bfd77d25-d230-436a-a85a-b28b3dbdb814"
```

These values most probably won't change in the future but you can always obtain them using the OpenStack command line interface.

This command will give the ID of the external (public) network:
```
ubuntu@k8s-controller:~/kubespray$ openstack network list
+--------------------------------------+--------------------+--------------------------------------+
| ID                                   | Name               | Subnets                              |
+--------------------------------------+--------------------+--------------------------------------+
| 5241cd94-029e-4e3a-a821-ca39dfef50d0 | cloudforms_network | d076777e-d330-472d-9fa1-9e70e2c77f1a |
| bfd77d25-d230-436a-a85a-b28b3dbdb814 | public             | 6a76d326-9997-4103-993a-c66053df7aaf |
+--------------------------------------+--------------------+--------------------------------------+
```

The following command will list the IP addresses of the DNS nameservers of the internal cloudforms network, which is the default for Sanger OpenStack. We also need to provide the Subnet ID (`d076777e-d330-472d-9fa1-9e70e2c77f1a`):
```
ubuntu@k8s-controller:~/kubespray$ openstack subnet show d076777e-d330-472d-9fa1-9e70e2c77f1a -f value -c dns_nameservers
172.18.255.1, 172.18.255.2
```

`floatingip_pool` defines a pool of IP addresses which should be taken from the public network.

### User-defined variables

General names:

* `cluster_name="my-k8s-cluster"` - define a unique (for your tenant) cluster name
* `network_name="my-k8s-network"` - define a unique (for your tenant) network name

Kubernetes nodes flavors (sizes):
* `flavor_k8s_master="8002"` - flavor for the master node
* `flavor_k8s_node="8002"` - flavor for the working node
* `flavor_etcd="8002"` - flavor for `etcd` node
* `flavor_bastion="8002"` - flavor for `bastion` node (traffic redirection)

To list all possible flavors you can use the following command:
```
ubuntu@k8s-controller:~/kubespray$ openstack flavor list
+------+------------+--------+------+-----------+-------+-----------+
| ID   | Name       |    RAM | Disk | Ephemeral | VCPUs | Is Public |
+------+------------+--------+------+-----------+-------+-----------+
| 2000 | m1.tiny    |   8600 |   15 |         0 |     1 | True      |
| 2001 | m1.small   |  17200 |   31 |         0 |     2 | True      |
| 2002 | m1.medium  |  34400 |   62 |         0 |     4 | True      |
| 2003 | m1.large   |  68800 |  125 |         0 |     8 | True      |
| 2004 | m1.xlarge  | 137600 |  250 |         0 |    16 | True      |
| 2005 | m1.2xlarge | 223600 |  406 |         0 |    26 | True      |
| 2006 | m1.3xlarge | 464400 |  844 |         0 |    54 | True      |
| 8000 | o1.tiny    |   1070 |    1 |         0 |     1 | True      |
| 8001 | o1.small   |   2140 |    3 |         0 |     2 | True      |
| 8002 | o1.medium  |   4280 |    8 |         0 |     4 | True      |
| 8003 | o1.large   |   8560 |   15 |         0 |     8 | True      |
| 8004 | o1.xlarge  |  17120 |   31 |         0 |    16 | True      |
| 8005 | o1.2xlarge |  27820 |   50 |         0 |    26 | True      |
| 8006 | o1.3xlarge |  57780 |  105 |         0 |    54 | True      |
| 8007 | o1.4xlarge | 115560 |  210 |         0 |    54 | True      |
+------+------------+--------+------+-----------+-------+-----------+
```

Instance image to be used for Kubernetes nodes (we use the default one with the preinstalled Docker):
* `image="xenial-isg-docker-c52f7acc02b0c11d41b174707e4c271b16f52996"`
* `ssh_user="ubuntu"`

Location of the public key (it will be used for interaction between all of the cluster nodes):
* `public_key_path="~/.ssh/id_rsa.pub"`

Number of Kubernetes nodes (we ask for 1 master, 1 bastion and 2 nodes):

* `number_of_bastions=1`
* `number_of_k8s_masters=0`
* `number_of_k8s_masters_no_floating_ip=1`
* `number_of_k8s_masters_no_etcd=0`
* `number_of_k8s_masters_no_floating_ip_no_etcd=0`
* `number_of_etcd=0`
* `number_of_k8s_nodes=0`
* `number_of_k8s_nodes_no_floating_ip=2`
* `number_of_gfs_nodes_no_floating_ip=0`

### Shared Volume

To create a shared volume between the Kubernetes nodes we use [GlusterFS](https://docs.gluster.org/en/latest/). GlusterFS is a scalable network filesystem suitable for data-intensive tasks such as cloud storage and media streaming. GlusterFS is free and open source software and can utilize common off-the-shelf hardware. To describe GlusterFS in the Terraform configuration file you can use the following variables:

* `flavor_gfs_node = "8002"`
* `image_gfs = "xenial-isg-docker-c52f7acc02b0c11d41b174707e4c271b16f52996"`
* `number_of_gfs_nodes_no_floating_ip = "2"`
* `gfs_volume_size_in_gb = "50"`
* `ssh_user_gfs = "ubuntu"`

Now you can run

```
sanger/terr.sh
```

### Ansible

To run Ansible please follow these instructions: https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#ansible

Before running Ansible, make sure to update the `openstack_lbaas_subnet_id` variable in `group_vars/all.yml` the with the `network_id` parameter created by terraform:
```
terraform show terraform.tfstate | grep ' network_id'
```

Also when you get to the `configuring OpenStack Neutron ports for __calico__` section please follow Theo's instructions on that and run the following one line (thanks to David Jackson!) substituting the $CLUSTER_NAME with your own cluster names defined in the terraform configuration file:
```
neutron port-list -c id -c device_id  | grep -E $(nova list | grep $CLUSTER_NAME | awk '{print $2}' | xargs echo | tr ' ' '|') | awk '{print $2}' | xargs -n 1 -I XXX echo neutron port-update XXX --allowed_address_pairs list=true type=dict ip_address=10.233.0.0/18 ip_address=10.233.64.0/18 | bash -eEx
```

Now go back to the root `kubespray` directory and run ansible following these instructions: https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#deploy-kubernetes

At this step we found a bug for which we created a pull request (https://github.com/kubernetes-incubator/kubespray/pull/3079), but it was not added to the 2.5.0 release of kubespray, therefore we added it manually to this repository

▶ vi ~/.ssh/cellgeni-su-farm4

~/production
▶ chmod 600 ~/.ssh/cellgeni-su-farm4

```
Host 10.0.0.*
       ProxyCommand ssh -W %h:%p bastion
       User ubuntu
       IdentityFile ~/.ssh/cellgeni-su-farm4
       ForwardX11 yes
       ForwardAgent yes
       ForwardX11Trusted yes
Host bastion
       Hostname BASTION_IP
       User ubuntu
       IdentityFile ~/.ssh/cellgeni-su-farm4
       ControlMaster auto
       ControlPath ~/.ssh/ansible-%r@%h:%p
       ForwardX11 yes
       ForwardAgent yes
       ForwardX11Trusted yes
Host master
       Hostname MASTER_IP
       IdentityFile ~/.ssh/cellgeni-su-farm4
       ProxyCommand ssh -W %h:%p bastion
       User ubuntu
```

Follow the kubectl instructions: https://github.com/kubernetes-incubator/kubespray/tree/master/contrib/terraform/openstack#set-up-kubectl

```
▶ ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -l ubuntu -Nf -L 
```

```
▶ lsof -ti:16443 | xargs kill -9
```