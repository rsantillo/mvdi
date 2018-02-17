#!/usr/bin/env bash
# Filename:                mkdiff.sh
# Description:             Creates an instance of VM
# Time-stamp:              <2018-02-17 14:07:30 fultonj> 
# -------------------------------------------------------
# SSH into $dom0 (the hypervisor) and create an instance
# of the base image stored as diffs on top of it
# -------------------------------------------------------
dom0='192.168.0.202'
diff='192.168.0.203'
REDEFINE=1
# -------------------------------------------------------
# Prerequisite, the following must already exist on dom0 
#  /var/lib/libvirt/images/base.qcow2
#  /usr/share/virsh-templates/base.xml
# -------------------------------------------------------
# I. If the old diff is up, shut it down
# 
# II. ssh into dom0 to: 
#   1. destroy diff
#   2. on top of base image make new diff
#   3. set new diff hostname
#   4. boot diff on network and install ssh key 
# 
# III. ssh into new diff VM to: 
#   1. update /etc/hosts and /etc/resolv.conf
#   2. configures chrony (ntp)
#   3. add the stack user with SSH key
#   4. verify it can reach centos.org
#   5. install yum priorities and packages
# -------------------------------------------------------
echo "This will take 10 minutes"
# -------------------------------------------------------
if ping -c 1 -w 5 "$diff" &>/dev/null ; then 
    echo "$diff is up"
fi
# -------------------------------------------------------
if ! ping -c 1 -w 5 "$dom0" &>/dev/null ; then 
    echo "$dom0 is down"
    exit 1
fi

## workaround NIC not coming up on first boot
if [[ $REDEFINE -eq 1 ]]; then

    echo "Shutting down and undefining diff"
    ssh root@$dom0 'virsh destroy diff'
    ssh root@$dom0 'virsh undefine diff'

    echo "Deleting diff image"
    ssh root@$dom0 'rm -f /var/lib/libvirt/images/diff.qcow2'

    echo "Creating diff from image"

    ssh root@$dom0 'qemu-img create -f qcow2 -b /var/lib/libvirt/images/diff-base-image.qcow2 /var/lib/libvirt/images/diff.qcow2'

    ssh root@$dom0 'virsh define /usr/share/virsh-templates/diff.xml'

    echo "Setting hostname"
    ssh root@$dom0 'virt-customize -a /var/lib/libvirt/images/diff.qcow2 --hostname diff.cloud.lab.eng.bos.redhat.com'

    echo "Updating image's ifcfg-eth{0,1}"

    ssh root@$dom0 "virt-customize -a /var/lib/libvirt/images/diff.qcow2 --run-command  'cat /dev/null > /etc/sysconfig/network-scripts/ifcfg-eth0 ; echo \"DEVICE=eth0\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"TYPE=Ethernet\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"ONBOOT=yes\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"BOOTPROTO=none\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"NETWORKING_IPV6=no\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"IPV6_AUTOCONF=no\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"DEFROUTE=no\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"NETMASK=255.255.255.0\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; echo \"IPADDR=192.168.24.1\" >> /etc/sysconfig/network-scripts/ifcfg-eth0; chcon system_u:object_r:net_conf_t:s0 /etc/sysconfig/network-scripts/ifcfg-eth0'"

    echo "Installing fultonj's public SSH key in root's home dir of image" 

    ssh root@$dom0 "virt-customize -a /var/lib/libvirt/images/diff.qcow2 --run-command 'mkdir /root/.ssh/; chmod 700 /root/.ssh/; echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1GKRg6YvBUUcQlrQJwEtnXymy9Jm/+IAgHXP2XlesNSjupfxWOGu4enGGUw1onDgqbbmF+7iyXqr42GHoYOTYa7b51dQJGuGTJhHgaxf6dGqdCixOBk1/M9yu/mlSGO3qUySlSarIAuQqbmrRNogviJS/UQ/05CiU044+rRaodqUNpgKlhA32Z6CTyQKft6SJCkVzfDGK1bbEWpG+ik2tmq0+5JkFR+lSDiocV1OobxsCeutAcFj6UuKxIbZlclQeNFg78aXEvI7hOHB8Fa1FPSZcJgbswbajVa6kCJjdjNBIBT1RWFAzf3iKmiWXZgg7E+qWuvwna32cCQCcozeB jfulton@runcible.example.com > /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys; chcon system_u:object_r:ssh_home_t:s0 /root/.ssh ; chcon unconfined_u:object_r:ssh_home_t:s0 /root/.ssh/authorized_keys '"

    echo "Starting new diff and sleeping 60 seconds for it to boot"
    ssh root@$dom0 'virsh start diff'

    sleep 60
fi

# -------------------------------------------------------
if ! ping -c 1 -w 5 "$diff" &>/dev/null ; then 
    echo "$diff is down"
    exit 1
fi

echo "Updating /etc/resolv.conf"
ssh root@$diff "cat /dev/null > /etc/resolv.conf"
ssh root@$diff "echo 'search example.com' >> /etc/resolv.conf"
ssh root@$diff "echo 'nameserver 192.168.0.1' >> /etc/resolv.conf"

echo "Updating /etc/hosts"
ssh root@$diff 'echo "192.168.0.202    igor" >> /etc/hosts'

echo "Updating /etc/chrony.conf and restarting chronyc"
ssh root@$diff "cat /dev/null > /etc/chrony.conf"
ssh root@$diff "echo 'server 0.pool.ntp.org iburst' >> /etc/chrony.conf"
ssh root@$diff "echo 'server 1.pool.ntp.org iburst' >> /etc/chrony.conf"
ssh root@$diff "echo 'server 2.pool.ntp.org iburst' >> /etc/chrony.conf"
ssh root@$diff "echo 'server 3.pool.ntp.org iburst' >> /etc/chrony.conf"

ssh root@$diff "echo 'driftfile /var/lib/chrony/drift' >> /etc/chrony.conf"
ssh root@$diff "echo 'logdir /var/log/chrony' >> /etc/chrony.conf"
ssh root@$diff "echo 'log measurements statistics tracking' >> /etc/chrony.conf"
ssh root@$diff "systemctl enable chronyd.service"
ssh root@$diff "systemctl stop chronyd.service"
ssh root@$diff "systemctl start chronyd.service"
ssh root@$diff "systemctl status chronyd.service"
ssh root@$diff "chronyc sources"

echo "Creating stack user"
ssh root@$diff 'useradd stack'
ssh root@$diff 'echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack'
ssh root@$diff 'chmod 0440 /etc/sudoers.d/stack'
ssh root@$diff 'mkdir /home/stack/.ssh/; chmod 700 /home/stack/.ssh/; echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1GKRg6YvBUUcQlrQJwEtnXymy9Jm/+IAgHXP2XlesNSjupfxWOGu4enGGUw1onDgqbbmF+7iyXqr42GHoYOTYa7b51dQJGuGTJhHgaxf6dGqdCixOBk1/M9yu/mlSGO3qUySlSarIAuQqbmrRNogviJS/UQ/05CiU044+rRaodqUNpgKlhA32Z6CTyQKft6SJCkVzfDGK1bbEWpG+ik2tmq0+5JkFR+lSDiocV1OobxsCeutAcFj6UuKxIbZlclQeNFg78aXEvI7hOHB8Fa1FPSZcJgbswbajVa6kCJjdjNBIBT1RWFAzf3iKmiWXZgg7E+qWuvwna32cCQCcozeB jfulton@runcible.example.com > /home/stack/.ssh/authorized_keys; chmod 600 /home/stack/.ssh/authorized_keys; chcon system_u:object_r:ssh_home_t:s0 /home/stack/.ssh ; chcon unconfined_u:object_r:ssh_home_t:s0 /home/stack/.ssh/authorized_keys; chown -R stack:stack /home/stack/.ssh/ '

echo "Verify I can reach centos.org"
ssh root@$diff "ping -c 1 centos.org"
sleep 3

echo "Installing yum-utils"
ssh root@$diff "yum install -y yum-plugin-priorities yum-utils"

echo "Listing repositories"
ssh root@$diff "yum repolist"

echo "Installing a few utility packages"
ssh root@$diff "yum install -y emacs-nox tree vim git bind-utils tmux nfs-utils rpcbind"

echo "Upgrading all packages to latest"
ssh root@$diff "yum upgrade -y"

# echo "rebooting $diff and waiting 60 seconds for reboot"
# ssh root@$diff "init 6"
# sleep 60

# if ! ping -c 1 -w 5 "$diff" &>/dev/null ; then 
#     echo "$diff is down"
#     exit 1
# fi

# make it easy to pull from git
ssh -A stack@$diff "echo 'git clone git@github.com:rsantillo/mvdi.git' >> sh_me"

echo "Updating /etc/fstab and mounting nas"
ssh root@$diff "mkdir /nas"
ssh root@$diff "echo '192.168.0.201:/volume1/mvdi       /nas nfs rsize=8192,wsize=8192,timeo=14,intr' >> /etc/fstab"
ssh root@$diff "mount /nas; ls /nas"

echo "$diff is ready"
ssh root@$diff "uname -a"

exit 0
