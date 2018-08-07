![Kubernetes Logo](https://raw.githubusercontent.com/kubernetes-incubator/kubespray/master/docs/img/kubernetes-logo.png)

Kubernetes Cluster on Sanger Institute OpenStack cloud
======================================================

## Prerequisites

You will need a Sanger OpenStack account. Consult the [wiki](https://ssg-confluence.internal.sanger.ac.uk/display/OPENSTACK/OpenStack) for information about getting an account and getting started.

If you already have an OpenStack account and forgot your password you can find it by logging in to [Cloudforms](https://cloudforms.internal.sanger.ac.uk/) with your Sanger credentials and going to Services/Catalogs/Reset OpenStack Password. Click the `Order` button and then copy your previous password and click `Cancel`. This password will also be needed in one of the next steps.

## High-level overview of the process

To setup a Kubernetes cluster we will use Terraform and Ansible. Terraform creates instances in OpenStack, along with networks and volumes and all the other fiddly bits required for the Kubernetes cluster. Ansible provisions all the necessary software to those instances.

Both Terraform and Ansible are run from a controller instance which has to be created first.

All of the software have been nicely packaged into [kubespray](https://github.com/kubernetes-incubator/kubespray) GitHub repository. Here we are using version 2.5.0 of the kubespray, which was obtained by forking the original repository and resetting the head of the repository to the commit before the release of version 2.5.0:
```
git reset --hard 02cd541
git push -f origin master
```

All other changes were introduced by us with an enormous help of Helen Cousins (@HelenCousins), Theo Barber-Bany (@theobarberbany), Stijn van Dongen (@micans) and Anton Khodak (@anton-khodak). All of the changes are located in the `sanger` folder of the current repository.

### Setting up a controller instance

_run the following steps from your Sanger laptop or from a Sanger Linux desktop on a wired network_

* Using OpenStack credentials login to [Horizon dashboard](https://zeta.internal.sanger.ac.uk)/Instances and launch a clean Ubuntu Xenial instance with `o1.medium` flavour and associate a floating IP (e.g. 12.34.56.78) with it. When launching the instance import your public key (`~/.ssh/id_rsa.pub`) for easy ssh-ing. Give your instance a proper name, e.g. `k8s-controller`.

* Download your OpenStack RC File (Identity API v3) from [Horizon dashboard](https://zeta.internal.sanger.ac.uk) by going to `Project/Api Access`. This is your credentials for accessing the OpenStack command line interface.

* Copy your OpenStack RC File to your controller instance:

```
scp your-openrc.sh ubuntu@12.34.56.78:~
```

(your file name and ip address will be different)

* Login to your instance and source your OpenStack RC File:

```
ssh ubuntu@12.34.56.78
source your-openrc.sh
```

When asked provide your OpenStack password (see above). For the future, you can add your password directly to the `your-openrc.sh` file by substituting the following lines:

```
echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT
```

with the just the following line:

```
export OS_PASSWORD=YOUR_OPENSTACK_PASSWORD
```

Additionally, you can put the sourcing of the OpenStack RC File into your `.bashrc` (on this machine) so you never need to think about it again.

* Run the following commands which will install all the prerequisites for `kubespray`, additionally the Nextflow workflow engine (and Java, which it depends on) and `kubectl` client:

```
git clone https://github.com/cellgeni/kubespray.git
cd kubespray
sanger/pre.sh
```

## Terraforming

Terraform creates infrastructure from a simple text configuration file. [my-terraform-vars.tfvars](sanger/my-terraform-vars.tfvars) is an example of such a Terraform configuration file.

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

    # Install dependencies from ``requirements.txt``
    sudo -H pip install -r requirements.txt

    # Copy ``inventory/sample`` as ``inventory/mycluster``
    cp -rfp inventory/sample inventory/mycluster

    # Update Ansible inventory file with inventory builder
    declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
    CONFIG_FILE=inventory/mycluster/hosts.ini python3 contrib/inventory_builder/inventory.py ${IPS[@]}

    # Review and change parameters under ``inventory/mycluster/group_vars``
    cat inventory/mycluster/group_vars/all.yml
    cat inventory/mycluster/group_vars/k8s-cluster.yml

    # Deploy Kubespray with Ansible Playbook
    ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml

### Vagrant

For Vagrant we need to install python dependencies for provisioning tasks.
Check if Python and pip are installed:

    python -V && pip -V

If this returns the version of the software, you're good to go. If not, download and install Python from here <https://www.python.org/downloads/source/>
Install the necessary requirements

    sudo pip install -r requirements.txt
    vagrant up

Documents
---------

-   [Requirements](#requirements)
-   [Kubespray vs ...](docs/comparisons.md)
-   [Getting started](docs/getting-started.md)
-   [Ansible inventory and tags](docs/ansible.md)
-   [Integration with existing ansible repo](docs/integration.md)
-   [Deployment data variables](docs/vars.md)
-   [DNS stack](docs/dns-stack.md)
-   [HA mode](docs/ha-mode.md)
-   [Network plugins](#network-plugins)
-   [Vagrant install](docs/vagrant.md)
-   [CoreOS bootstrap](docs/coreos.md)
-   [Debian Jessie setup](docs/debian.md)
-   [openSUSE setup](docs/opensuse.md)
-   [Downloaded artifacts](docs/downloads.md)
-   [Cloud providers](docs/cloud.md)
-   [OpenStack](docs/openstack.md)
-   [AWS](docs/aws.md)
-   [Azure](docs/azure.md)
-   [vSphere](docs/vsphere.md)
-   [Large deployments](docs/large-deployments.md)
-   [Upgrades basics](docs/upgrades.md)
-   [Roadmap](docs/roadmap.md)


Community docs and resources
----------------------------

-   [kubernetes.io/docs/getting-started-guides/kubespray/](https://kubernetes.io/docs/getting-started-guides/kubespray/)
-   [kubespray, monitoring and logging](https://github.com/gregbkr/kubernetes-kargo-logging-monitoring) by @gregbkr
-   [Deploy Kubernetes w/ Ansible & Terraform](https://rsmitty.github.io/Terraform-Ansible-Kubernetes/) by @rsmitty
-   [Deploy a Kubernetes Cluster with Kubespray (video)](https://www.youtube.com/watch?v=N9q51JgbWu8)
