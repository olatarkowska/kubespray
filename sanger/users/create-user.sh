#/usr/bin/env bash
# $1 - username
mkdir $1 && cd $1
CA_LOCATION=/etc/kubernetes/ssl
openssl genrsa -out user.key 2048
sudo openssl req -new -key user.key -out user.csr -subj "/CN=$1/O=bitnami"
openssl x509 -req -in user.csr -CA $CA_LOCATION/ca.pem -CAkey $CA_LOCATION/ca-key.pem -CAcreateserial -out user.crt -days 500
