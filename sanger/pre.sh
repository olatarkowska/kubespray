export LC_ALL=C

# to get rid of `sudo: unable to resolve host` message
# https://askubuntu.com/questions/59458/error-message-sudo-unable-to-resolve-host-user
if [[ -z $HOSTNAME ]]; then
   HOSTNAME=$(cat /etc/hostname)
fi
if ! grep -qFw $HOSTNAME /etc/hosts; then
    echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts
fi

# Python and Ansible
sudo apt-get update
sudo apt install -y python
sudo apt-get install -y python-pip
sudo -H pip install --upgrade pip
sudo -H pip install python-openstackclient
sudo -H pip install netaddr
sudo -H pip install ansible
sudo apt install unzip

# Terraform version 0.11.7 (07/08/2018)
wget https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip
unzip terraform_0.11.7_linux_amd64.zip
sudo mv terraform /bin
rm terraform_0.11.7_linux_amd64.zip

# Java
sudo echo PURGE | sudo debconf-communicate oracle-java8-installer
sudo echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt update -y;sudo apt install -y oracle-java8-installer

# Nextflow
curl -s https://get.nextflow.io | bash
sudo mv nextflow /bin

# Kubectl
sudo snap install --classic kubectl

# generate a key pair
ssh-keygen -f ~/.ssh/id_rsa -q -N ""
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

