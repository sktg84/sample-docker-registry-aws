DESCRIPTION
============

  Example of how to deploy a private Docker registry in EC2 machines making use of S3 to back up the storage layer.
Pre-req:
========
install terraform as: 
 wget https://releases.hashicorp.com/terraform/1.1.9/terraform_1.1.9_linux_amd64.zip
 unzip terraform_1.1.9_linux_amd64.zip
 ./terraform -version
  echo $"export PATH=\$PATH:$(pwd)" >> ~/.bash_profile
  source ~/.bash_profile


Infra Creation:
================
  terraform init 
  terraform apply
  chmod 700 ./keys/*
  make ssh


Initial setup:
==============
In the ssh (it takes into ubuntu instance launched above):
sudo -i
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install docker-ce
mkdir /docker-registry/
docker run --rm -ti xmartlabs/htpasswd <username> <password> > /docker-registry/htpasswd

docker run -d -p 5000:5000 --privileged --restart=always --name s3-registry \
-v /docker-registry:/data:ro \
-e REGISTRY_STORAGE=s3 \
-e REGISTRY_STORAGE_S3_REGION=us-east-1 \
-e REGISTRY_STORAGE_S3_BUCKET=ksubram2-docker-registry-bucket \
-e REGISTRY_STORAGE_S3_ENCRYPT=false \
-e REGISTRY_STORAGE_S3_SECURE=true \
-e REGISTRY_STORAGE_S3_V4AUTH=true \
-e REGISTRY_STORAGE_S3_CHUNKSIZE=5242880 \
-e REGISTRY_STORAGE_S3_ROOTDIRECTORY=/image-registry \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/data/htpasswd \
registry:2


Configure:
=========
vi /etc/default/docker -->  insert the line below:
DOCKER_OPTS="--config-file=/etc/docker/daemon.json"

* Do docker ps and find the container id of registry. Do docker inspect <containerid> and find ip address

vi /etc/docker/daemon.json --> insert line below. NOTE: ip is the ip from step above...
{ "insecure-registries":["172.17.0.2:5000"] }

systemctl stop docker 
systemctl start docker

validate:
=======
docker login -u user  172.17.0.2:5000
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
 docker pull alpine:3.4   --> pull from docker hub
docker tag alpine:3.4 172.17.0.2:5000/alpine:3.4 -> tag to local
docker push 172.17.0.2:5000/alpine:3.4  --> push to local

curl -sSNL -u 'user:password' http://172.17.0.2:5000/v2/_catalog
{"repositories":["alpine"]}

 
 

KNOW MORE
=========
https://docs.docker.com/registry/deploying/
https://ops.tips/gists/aws-s3-private-docker-registry

https://icicimov.github.io/blog/docker/Docker-Private-Registry-with-S3-backend-on-AWS/
