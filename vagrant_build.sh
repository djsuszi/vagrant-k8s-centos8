#!/bin/bash

echo "[TASK 01] Update /etc/hosts"
cat /vagrant/tmp-hosts >>/etc/hosts
MASTER=$(cat /vagrant/tmp-hosts |head -n 2|tail -n 1|awk '{print $1}')
MASTERNAME=$(cat /vagrant/tmp-hosts |head -n 2|tail -n 1|awk '{print $2}')
MASTERCIDR=$(echo $MASTER.0/24|cut -f -3,5 -d.)


if [ $(hostname) != "${MASTERNAME}" ] ; then 
	echo "[TASK 02] Getting CACHE"
	# getting dnf cache via SSH from Master if local cache file is empty
	test ! -f /vagrant/cache/dnf-cache.tar.gz \
	&& scp -r -i /vagrant/vagrant_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER}:/var/cache/dnf/* /var/cache/dnf/
fi
tar -xzvf /vagrant/cache/dnf-cache.tar.gz -C /


echo "[TASK 10] Initial update"
echo "keepcache=1" >> /etc/dnf/dnf.conf
#yum --nogpg -y update
yum --nogpg -y -q install epel-release
yum --nogpg -y -q install figlet

figlet START  $(hostname)

figlet PRE-REQISITES

echo "[TASK 20] Install Docker Container Engine"
dnf --nogpgcheck install -y -q yum-utils curl unzip git wget pv > /dev/null 2>&1
dnf --nogpgcheck config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf --nogpgcheck install docker-ce --nobest -y

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF


echo "[TASK 21] Enable and Start Docker Service"
systemctl enable docker
systemctl start docker 

echo "[TASK 22 ] Loading cached docker images"
if [ $(hostname) != "${MASTERNAME}" ] ; 
then 
	echo "[TASK 23] Getting Docker images"
	# getting images via SSH from Master if local docker cache is empty
	test -z "$(ls -1 /vagrant/cache/dock*bz2)" \
	 && dockerimages=$(ssh -i /vagrant/vagrant_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER} "docker image ls -q") \
	 || ls -1 /vagrant/cache/docker-*bz2|while read image; do echo "local image ${image} loading"; cat ${image}|pv|bunzip2|docker load; done
	for image in $dockerimages; do
	echo "Getting image $image from ${MASTERNAME}"
	ssh -i /vagrant/vagrant_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER} "docker save $image|bzip2" 2>/dev/null |pv|bunzip2|docker load 
	done
else
	ls -1 /vagrant/cache/docker-*bz2|while read image; do cat ${image}|pv|bunzip2|docker load; done
fi


echo "[TASK 30] Disable SELinux & Firewall"
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
systemctl disable firewalld >/dev/null 2>&1
systemctl stop firewalld


echo "[TASK 40] Add Sysctl Settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 50] Disable and Turn Off SWAP"
swapoff -a && sed -i '/swap/d' /etc/fstab && rm -rf /swapfile

echo "[TASK 60] Add yum Repo File For Kubernetes"
cat >>/etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

echo "[TASK 61] Install kubeadm, kubelet and kubectl"
yum --nogpg install -y -q kubeadm-1.15.3 kubelet-1.15.3 kubectl-1.15.3 >/dev/null 2>&1

echo "[TASK 62] Enable and Start Kubelet Service"
systemctl enable kubelet >/dev/null 2>&1
systemctl start kubelet >/dev/null 2>&1

echo "[TASK 70] Enable SSH Password Authentication"
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd


#echo "[TASK 71] Setting Root Password"
#echo KubeAdmin | passwd --stdin root >/dev/null 2>&1
#echo "export TERM=xterm" >> /etc/bashrc





if [ $(hostname) == "${MASTERNAME}" ] ; then 

figlet MASTER
yum --nogpg install -q -y tc

echo "[TASK 101] Start Kubernetes Cluster ${MASTER} ${MASTERCIDR}"
kubeadm init --apiserver-advertise-address=${MASTER} --pod-network-cidr=${MASTERCIDR} |tee -a /root/kubeinit.log # 2>/dev/null

echo "[TASK 102] Generate Join Command To Cluster For Worker Nodes"
kubeadm token create --print-join-command > /join_worker_node.sh
su - vagrant -c "kubectl taint nodes --all node-role.kubernetes.io/master-"

echo "[TASK 103] Copy SSH Key for root"
mkdir -p /root/.ssh/
cat /vagrant/vagrant_rsa.pub > /root/.ssh/authorized_keys

else

figlet WORKER

echo "[TASK 201] Join Node To Kubernetes Cluster ${MASTER}"
#yum --nogpg install -q -y sshpass >/dev/null 2>&1
#sshpass -p KubeAdmin scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER}:/join_worker_node.sh /join_worker_node.sh 2>/dev/null
scp -i /vagrant/vagrant_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER}:/join_worker_node.sh /join_worker_node.sh 2>/dev/null
bash /join_worker_node.sh 2>&1
 
echo "[TASK 202] Copy Kube Config To Vagrant User .kube Directory"
#sshpass -p KubeAdmin scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER}:/etc/kubernetes/admin.conf /etc/kubernetes/admin.conf 2>/dev/null
scp -i /vagrant/vagrant_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${MASTER}:/etc/kubernetes/admin.conf /etc/kubernetes/admin.conf 2>/dev/null

su - vagrant -c "kubectl label node $(hostname) node-role.kubernetes.io/worker=worker"

fi

echo "[TASK 301] Copy Kube Config To Vagrant User .kube Directory"
mkdir /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo "[TASK 302] Copy Kube Config To Root User .kube Directory"
mkdir /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown -R root:root /root/.kube

if [ $(hostname) != "${MASTERNAME}" ] ; then 
su - vagrant -c "kubectl label node $(hostname) node-role.kubernetes.io/worker=worker"
fi

figlet END  $(hostname)


#some usefull trash
#dnf clean all
# https://kubernetes.io/docs/reference/kubectl/cheatsheet/
# kubectl apply -f /vagrant/vagrant_busybox_replica.yaml
# kubectl get nodes -o wide
# kubectl get pods --all-namespaces -o wide --show-labels
# kubectl get rs
# kubectl get svc
# kubectl get pods --no-headers=true|cut -f 1 -d " " | xargs  kubectl delete pod
# kubectl delete pod $(kubectl get pods -o wide|grep CrashLoopBackOff|cut -f 1 -d' '|xargs)
#tar -czvf /vagrant/cache/dnf-cache.tar.gz /var/cache/dnf/
#docker image ls -q|while read image; do docker save $image|bzip2|pv > /vagrant/cache/docker-${image}.bz2 ; done
