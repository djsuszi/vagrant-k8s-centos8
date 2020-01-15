# Kubernetes on Centos with Vagrant

Goal was creating IaC for booting k8s cluster on local machine.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine.

### Prerequisites

Install [Vagrant from Hashicorp](https://www.vagrantup.com/downloads.html) and [Oracle Virtualbox](https://www.virtualbox.org/wiki/Downloads)

for Virtualbox version > 6.0 you might to change few settings, because Vagrant 2.2.6 is not working with newest 6.1 Virtualbox
for example:
https://blogs.oracle.com/scoter/getting-vagrant-226-working-with-virtualbox-61-ga
```
add to file: 
vagrant/embedded/gems/2.2.6/gems/vagrant-2.2.6/plugins/providers/virtualbox/driver/meta.rb
  "6.1" => Version_6_1,
at end of "driver_map" list

create vagrant/embedded/gems/2.2.6/gems/vagrant-2.2.6/plugins/providers/virtualbox/driver/version_6_1.rb

add to file: 
vagrant/embedded/gems/2.2.6/gems/vagrant-2.2.6/plugins/providers/virtualbox/plugin.rb
      autoload :Version_6_1, File.expand_path("../driver/version_6_1", __FILE__)
at the end of "module Driver" section
```

### Installing and Running

Just clone repository in your Vagrant dedicated directory:
```
git clone https://github.com/djsuszi/vagrant-k8s-centos8.git
```

Initialize vagrant Centos/8 file.

```
vagrant init centos/8 \
  --box-version 1905.1
```

Check your hosts and VM settings in "Vagrantfile"
You can set number of CPUs, Memory, hostname and IP (you should choose /24 network)
```
cluster = {
  "host1" => { :ip => "192.168.77.101", :cpus => 4, :mem => 2048 },
  "host2" => { :ip => "192.168.77.102", :cpus => 4, :mem => 2048 },
  "host3" => { :ip => "192.168.77.103", :cpus => 4, :mem => 2048 },
  "host4" => { :ip => "192.168.77.104", :cpus => 4, :mem => 1024 }
}
```

Top one will be always MASTER for Kubernetes, others will join to it.

You need to have access to ssh-keygen because at first start you will have generated 2048 bytes RSA ssh key to access root account:
private vagrant_root_sshkey
public vagrant_root_sshkey.pub
Public key is automated pasted to authorized_keys on all your new VMs.

You can use static root password if you prefere, just uncomment in vagrant_build.sh
Task: Setting Root Password
and change worker task 1 to installed use sshkey.

and basic commands: start / halt / destroy 
```
vagrant up
vagrant halt
vagrant destroy -f

```

## Running some tests

You can run included basic tests for K8S cluster.

### simple replication controller

Just run from vagrant account in VM:
```
kubectl apply -f /vagrant/vagrant_busybox_replica.yaml
kubectl get nodes -o wide
kubectl get pods --all-namespaces -o wide --show-labels
kubectl get rs
kubectl get pods --no-headers=true|cut -f 1 -d " " | xargs  kubectl delete pod
kubectl delete pod $(kubectl get pods -o wide|grep CrashLoopBackOff|cut -f 1 -d' '|xargs)
```

### simple deploy scenario

Just run from vagrant account in VM prepared script:
```
sh /vagrant/vagrant_busybox_deploy_test.sh
```

## Security

by default firewall and selinux are disabled (it's just vagrant local machine Lab :))

On Production or outside envirement you should take care of Security,
at first try to do some [hardening !!](https://highon.coffee/blog/security-harden-centos-7/)

You can make multimaster K8S, but you need at least 3 master nodes to setup proper etcd cluster.

## Faster vagrant build up

Only first Centos VM is getting lots of data from outside repositories.
Next VMs are sharing downloaded RPM and docker images from first Master machine.
To make lower number or request there is "--nogpg" flag for yum and dnf (you can remove it from vagrant_build.sh script).

### Even fastest build up :)

After first running MASTER, you can prepare cache files and keep it in your Vagrant foler in "cache" directory
```
tar -czvf /vagrant/cache/dnf-cache.tar.gz /var/cache/dnf/
docker image ls -q|while read image; do docker save $image|bzip2|pv > /vagrant/cache/docker-${image}.bz2 ; done
```

and then scp all files from VM directory /var/cache/ to folder with your Vagrantfile
```
mkdir ./cache
scp -i vagrant_root_sshkey root@MASTER_IP:/vagrant/cache/* ./cache
```

## Contributing

You can fork and push some bugs if you want.

## Acknowledgments

* Hat tip to anyone whose idea was used
* Hashicorp for Vagrant features
* Brian Foks & Chet Ramey for Bash 

## Additional help

* [vagrant on Ubuntu](https://phoenixnap.com/kb/how-to-install-vagrant-on-ubuntu)
* [vagrant on Centos](https://phoenixnap.com/kb/how-to-install-vagrant-on-centos-7)
* [HA K8s](https://kubernetes.io/docs/tasks/administer-cluster/highly-available-master/)
* [Multi Master K8s](http://dockerlabs.collabnix.com/kubernetes/beginners/Install-and-configure-a-multi-master-Kubernetes-cluster-with-kubeadm.html)


## TODO

Multi master K8s setup
NFS between VMs
move install commands to Ansible playbook
you can move install script to Vagrantfile between "SHELL"

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

