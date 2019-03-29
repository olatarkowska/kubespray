#!/bin/bash

set -eux

ip=$1
cluster_name="lustre"
#. my-terraform-vars.tfvars

server=$(openstack server list | grep $ip | awk '{print $2}')

portcount=$(openstack port list --server $server | grep lport | wc -l)
if [ $portcount -eq 0 ]; then echo 'yay'; else exit 0; fi

name=$(echo $cluster_name)$(echo $server)lport

lnet=$(openstack network list | grep -i lnet | awk '{print $2}')

port=$(openstack port create --network $lnet $name -f json | jq -r '.id')
openstack server add port $server $port

# ON BASTION
# lusnet=$(ssh $ip "ip a" | grep ens[4-9] | awk '{print $2}' | sed -e  's/://')
# echo "auto $lusnet" > a
# echo "iface $lusnet inet dhcp" >> a
# scp a $ip:a
# ssh $ip "sudo mv a /etc/network/interfaces.d/60-lus.cfg"
# ssh $ip "sudo sed -i 's/#//' /etc/fstab"
# #ssh $ip "sudo sed -i 's/noauto/auto/' /etc/fstab"
# ssh $ip 'sudo mount -t lustre lus06-mds1@tcp0:lus06-mds2@tcp0:/lus06 /lustre/secure'
#
# ssh $ip sudo reboot
