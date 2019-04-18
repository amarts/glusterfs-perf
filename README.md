glusterfs.perf
=========

On a given set of hosts, create a testbed to test GlusterFS builds.
glusterfs.perf role:
  * Installs the necessary packages to build GlusterFS from source.
  * Clones the GlusterFS repository
  * Buils the filesystem from source and installs
  * Creates a GlusterFS volume and mounts it

Requirements
------------

Ansible >= 2.7
gluster-ansible

Role Variables
--------------

| Name                     |Choices| Default value         | Comments                          |
|--------------------------|-------|-----------------------|-----------------------------------|
| glusterfs_perf_volume_state | present/absent/started/stopped | present | GlusterFS volume state.  |
| glusterfs_perf_volume | | UNDEF | Name of the gluster volume |
| glusterfs_perf_bricks | | UNDEF | GlusterFS brick directories for volume creation |
| glusterfs_perf_hosts  | | UNDEF | List of hosts that will be part of the cluster  |
| glusterfs_perf_transport | tcp/tcp,rdma | tcp | Transport to be configured while creating volume |
| glusterfs_perf_replica_count | | Omitted by default | Replica count for the volume |
| glusterfs_perf_arbiter_count | | Omitted by default | Arbiter count for the volume |
| glusterfs_perf_disperse_count | | Omitted by default | Disperse count for the volume |
| glusterfs_perf_redundancy_count | | Omitted by default | Redundancy count for the volume |
| glusterfs_perf_force | yes/no | no | Whether GlusterFS volume should be created by force |
| glusterfs_perf_mountpoint | | /mnt/glusterfs | GlusterFS mount point |
| glusterfs_perf_server | | UNDEF | Server to use while mounting GlusterFS volume |
| glusterfs_perf_clients | | | Clients on which to mount the volume and run the tests|
| glusterfs_perf_client | | First among the list of clients | Client on which to mount. This will the client where the perf test is launched. |
| glusterfs_perf_resdir | | /var/tmp/glusterperf | Directory to store perf results|
| glusterfs_perf_mail_sender || sac@redhat.com | email address which has to be listed in the from field of the status email. |
| glusterfs_perf_to_list || UNDEF | email addresses of the list of people to whom the report has to be sent. Not this is not comma separated addresses, but yaml list. Plese see playbooks/cluster_setup.yml for an example. |
| glusterfs_perf_ofile || /tmp/perf-results-<date> | Output file where results have to be stored |
| glusterfs_perf_git_repo | | https://github.com/gluster/glusterfs.git | Set the URL of new repo to be cloned |
| glusterfs_perf_git_refspec | | - | Details of particular patch to be fetched. Check the details in 'Download' section in gerrit for refspec details |


Example Playbook
----------------

```
---
- name: Setup a GlusterFS cluster from source tree
  remote_user: root
  gather_facts: true
  hosts: all
  vars:
    glusterfs_perf_volume: perfvol
    glusterfs_perf_bricks: /gluster_bricks/perfbrick
    glusterfs_perf_hosts: "{{ groups['all'] }}"
    glusterfs_perf_replica_count: 2
    glusterfs_perf_server: "{{ groups['all'][0] }}"

  roles:
    - glusterfs.perf
```

Setting up and running the tests
--------------------------------
Bootstrapping: Ensure Ansible >= 2.7 is present.
Install the roles gluster-ansible-infra and glusterfs-perf.
Copy the playbook under playbooks/cluster_setup.yml directory in the
glusterfs-perf role and change the variables appropriately and run the command:

\# gluster-ansible -i \<inventory-file\> cluster_setup.yml

To run the role on a local setup:

1. On the host machine, fetch all the roles:
   - gluster-ansible-infra
   - gluster-ansible-cluster
   - gluster-ansible-roles

   Fetch the glusterfs.perf role too
   ```
   $ cd /etc/ansible/roles
   $ git clone https://github.com/gluster/glusterfs-perf.git
   $ mv glusterfs-perf glusterfs.perf
   ```

2. Skip this step if you need to run on existing systems

   ```
   $ mkdir ~/glusterfs-perf-vagrant/

   copy the below below content to Vagrantfile
   $ cat ~/glusterfs-perf-vagrant/Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :

driveletters = ('a'..'z').to_a

Vagrant.configure("2") do |config|

  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/home/vagrant/sync", disabled: true
  config.vm.box = "centos/7"
  host_vars = {}
  (1..3).each do |i|
    config.vm.define vm_name = "centos#{i}" do |vm|
      vm.vm.hostname = vm_name
      vm.vm.provider :libvirt do |lv|
        lv.default_prefix = "gp"
        lv.cpus = 4
        lv.memory = 4096
        lv.nested = false
        lv.cpu_mode = "host-passthrough"
        lv.volume_cache = "writeback"
        lv.graphics_type = "none"
        lv.video_type = "vga"
        lv.video_vram = 1024
        # lv.usb_controller :model => "none"  # (requires vagrant-libvirt 0.44 which is not in Fedora yet)
        lv.random :model => 'random'
        lv.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
        lv.storage :file, :device => "sdb", :size => '1024G'
      end
      $script = <<-SCRIPT
      sudo sed -i -e "\\#PasswordAuthentication no# s#PasswordAuthentication no#PasswordAuthentication yes#g" /etc/ssh/sshd_config
      SCRIPT
      $sshrestart = "sudo systemctl restart sshd"
      config.vm.provision "shell", inline: $script
      config.vm.provision "shell", inline: $sshrestart
    end
  end
end

   $ cd ~/glusterfs-perf-vagrant
   $ vagrant up
   $ for i in {1..3} ; do \
     new_ip=$(vagrant ssh centos$i -c "ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//'") ; \
     echo "$new_ip centos$i" >> /etc/hosts ; \
     done
   ```

3. Setup passwordless ssh from the host to all the nodes where the test will be run
   ```
   $ ssh-copy-id <NODES>
   ```

4. Create the inventory file
   ```
   $ cat ~/glusterfs-perf-vagrant/inventory.yml
   [servers]
   centos1
   centos2

   [clients]
   centos3
   ```

5. Run the ansible playbook with default values:
   ```
   $ ansible-playbook -i ~/glusterfs-perf-vagrant/inventory.yml /etc/ansible/roles/glusterfs.perf/playbooks/cluster_setup.yml --extra-vars  "ansible_sudo_pass=<ROOTPASSWD>"
   ```
   If you are running the vagrant setup mentioned, the root password will be "vagrant". To run a customised playbook, copy the cluster_setup.yml and change it accordingly, specify the modified plabook location in the above command.

    There are many tags that you can specify while running the playbook:
    - prereq
    - fio

License
-------

GPLv3
