#!/usr/bin/env bash
# Filename:                mkdiff.sh
# Description:             Creates an instance of VM
# Time-stamp:              <2018-02-17 14:35:35 fultonj> 
# -------------------------------------------------------
# SSH into $dom0 (the hypervisor) and create an instance
# of the base image stored as diffs on top of it
# -------------------------------------------------------
dom0='192.168.0.202'
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
# -------------------------------------------------------
echo "Don't blink..."
# -------------------------------------------------------
if ! ping -c 1 -w 5 "$dom0" &>/dev/null ; then 
    echo "$dom0 is down"
    exit 1
fi

echo "Shutting down and undefining diff"
ssh root@$dom0 'virsh destroy diff'
ssh root@$dom0 'virsh undefine diff'

echo "Deleting diff image"
ssh root@$dom0 'rm -f /var/lib/libvirt/images/diff.qcow2'

echo "Creating diff from image"

ssh root@$dom0 'qemu-img create -f qcow2 -b /var/lib/libvirt/images/base.qcow2 /var/lib/libvirt/images/diff.qcow2'

ssh root@$dom0 'virsh define /usr/share/virsh-templates/diff.xml'

echo "Starting new diff"
ssh root@$dom0 'virsh start diff'

exit 0
