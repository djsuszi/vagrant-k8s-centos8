# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

#make sure that IPs are in /24 network
cluster = {
  "host1" => { :ip => "192.168.77.101", :cpus => 4, :mem => 2048 },
  "host2" => { :ip => "192.168.77.102", :cpus => 4, :mem => 2048 },
  "host3" => { :ip => "192.168.77.103", :cpus => 4, :mem => 2048 },
  "host4" => { :ip => "192.168.77.104", :cpus => 4, :mem => 1024 }
}

#Generating new sshkey  
system('test ! -f vagrant_rsa && ssh-keygen -t rsa -b 2048 -f vagrant_root_sshkey -q -N ""')

#Generating hosts file
system('echo "#k8s hosts" > tmp-hosts')
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  cluster.each_with_index do |(hostname, info), index|
	system("echo #{info[:ip]} #{hostname} #{hostname}.example.com >> tmp-hosts")
  end # end cluster
end

 
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  cluster.each_with_index do |(hostname, info), index|

    config.vm.define hostname do |cfg|
      cfg.vm.provider :virtualbox do |vb, override|
#		config.vm.boot_timeout = 900   # you can set it, if you have slower host

		config.vm.box = "centos/8"
		config.vm.box_version = "1905.1"
		
		config.ssh.forward_agent = true
		
		config.vm.provision "vagrant_build", type: "shell", path: "vagrant_build.sh"

# INLINE SHELL	
#		config.vm.provision "shell", inline: <<-SHELL
#		sudo apt-get update
#		sudo apt-get install -y apache2
#		sudo hostname > /nazwa_hosta
#		SHELL

# ANSIBLE
#		config.vm.provision :ansible do |ansible|
#			ansible.playbook = "playbook.yml"
#			ansible.verbose = "vv"
#			ansible.sudo = true
#		end
		
        override.vm.network :private_network, ip: "#{info[:ip]}"
        override.vm.hostname = hostname
		vb.linked_clone = true
        vb.name = hostname
#		vb.gui = true
        vb.customize ["modifyvm", :id, "--memory", info[:mem], "--cpus", info[:cpus], "--hwvirtex", "on"]
      end # end provider
	

    end # end config

  end # end cluster
  
end

