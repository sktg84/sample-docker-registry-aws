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
  
Manual configs -- Pre-req:
==========================
[root@ip-172-31-11-145 bpa-docker-registry-aws]# ls -al ~/.aws/
total 8
drwxr-xr-x 2 root root  39 Apr 20 08:34 .
dr-xr-x--- 9 root root 249 May  2 11:37 ..
-rw-r--r-- 1 root root  39 Apr 20 06:51 config
-rw-r--r-- 1 root root 113 Apr 20 08:34 credentials

[root@ip-172-31-11-145 bpa-docker-registry-aws]# cat ~/.aws/config
[default]
region=us-west-2
output=json

[root@ip-172-31-11-145 bpa-docker-registry-aws]# cat ~/.aws/credentials
[default]
aws_access_key_id=AKxxxxxxxxxxxxxxxxxxxxxx
aws_secret_access_key= Wt5xxxxxxxxxxxxxxxxxxxxx


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

curl -sSNL -u 'user:password' http://172.17.0.2:5000/v2/_catalog
{"repositories":["alpine","java"]}

curl -sSNL -u 'user:password' http://172.17.0.2:5000/v2/java/tags/list
{"name":"java","tags":["latest"]}

curl -sSNL -u 'user:password' http://172.17.0.2:5000/v2/alpine/tags/list
{"name":"alpine","tags":["3.4"]}
 
 
 Load Docker images from local
 ==============================
1. Pull the image that is desired and check in local repo:

 root@ip-172-31-28-123:~# docker pull node
Using default tag: latest
latest: Pulling from library/node
6aefca2dc61d: Pull complete
967757d56527: Pull complete
c357e2c68cb3: Pull complete
c766e27afb21: Pull complete
32a180f5cf85: Pull complete
3507b5066a40: Pull complete
fa4934a906af: Pull complete
fd7c6a234db2: Pull complete
e9fdaad45501: Pull complete
Digest: sha256:e5b7b349d517159246070bf14242027a9e220ffa8bd98a67ba1495d969c06c01
Status: Downloaded newer image for node:latest

root@ip-172-31-28-123:~# docker image ls
REPOSITORY               TAG                 IMAGE ID            CREATED             SIZE
node                     latest              738d733448be        12 days ago         995MB
java                     latest              d23bdf5b1b1b        5 years ago         643MB

2. Save the image as tarball 

root@ip-172-31-28-123:~# docker save --output node.tar node:latest

root@ip-172-31-28-123:~# ls -alh
total 973M
-rw-------  1 root root 973M May  3 09:26 node.tar

3. To load and validate remove the local image downloaded in step 1. 
 root@ip-172-31-28-123:~# docker image rm node
Untagged: node:latest
Untagged: node@sha256:e5b7b349d517159246070bf14242027a9e220ffa8bd98a67ba1495d969c06c01
Deleted: sha256:738d733448be00c72cb6618b7a06a1424806c6d239d8885e92f9b1e8727092b5

root@ip-172-31-28-123:~# docker images
REPOSITORY               TAG                 IMAGE ID            CREATED             SIZE
java                     latest              d23bdf5b1b1b        5 years ago         643MB

4. Load the tar file to local repo: 
root@ip-172-31-28-123:~# docker image load --input node.tar
a13c519c6361: Loading layer [==================================================>]  129.1MB/129.1MB
Loaded image: node:latest

root@ip-172-31-28-123:~# docker image ls
REPOSITORY               TAG                 IMAGE ID            CREATED             SIZE
node                     latest              738d733448be        12 days ago         995MB
java                     latest              d23bdf5b1b1b        5 years ago         643MB

5. Tag and load to the local registry as before:

root@ip-172-31-28-123:~# docker tag node:latest 172.17.0.2:5000/node:latest
root@ip-172-31-28-123:~# docker push 172.17.0.2:5000/node:latest
The push refers to repository [172.17.0.2:5000/node]
adcd0466d8b3: Pushed
a13c519c6361: Pushed
latest: digest: sha256:c566a021114bb1e47f7c701dda598b91dfa69101638b22a207414d481d4a9d49 size: 2215

6. Validate via _catalog call: 
root@ip-172-31-28-123:~# curl -sSNL -u 'user:password' http://172.17.0.2:5000/v2/_catalog
{"repositories":["alpine","java","node"]}
http://ec2-3-88-187-171.compute-1.amazonaws.com:5000/v2/_catalog


KNOW MORE
=========
https://docs.docker.com/registry/spec/api/
https://docs.docker.com/registry/deploying/
https://ops.tips/gists/aws-s3-private-docker-registry
https://icicimov.github.io/blog/docker/Docker-Private-Registry-with-S3-backend-on-AWS/
