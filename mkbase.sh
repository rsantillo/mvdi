#!/usr/bin/env bash
# Filename:                mkbase.sh
# Description:             How the base image was made
# Time-stamp:              <2018-02-17 14:01:34 fultonj> 
# -------------------------------------------------------
# base-image.qcow2 was copied from one of these:
#   https://cloud.centos.org/centos/7/images
# -------------------------------------------------------

if [[ ! -e base-image.qcow2 ]] ; then
    echo "fail: base-image.qcow2 is missing"
    exit 1
fi

virt-customize -a base-image.qcow2 --run-command 'echo -e "d\nn\n\n\n\n\nw\n" | fdisk /dev/sda'
virt-customize -a base-image.qcow2 --run-command 'xfs_growfs /'
virt-filesystems --long -h --all -a base-image.qcow2
virt-customize -a base-image.qcow2 --run-command 'yum remove cloud-init* -y' 
virt-customize -a base-image.qcow2 --root-password password:fluffy

echo "Create base.xml by running virt-install and following the directions below"
tail -15 mkbase.sh 
# -------------------------------------------------------
# base.xml was created manually by running the following:
# 
# virt-install --ram 16384 --vcpus 8 --os-variant rhel7 --disk path=/var/lib/libvirt/images/base.qcow2,device=disk,bus=virtio,format=qcow2 --import --noautoconsole --vnc --network network:default --name base
# 
# Followed by manual update to add the desired networks based on how
# dom0 is configured. The UUID was then deleted and it was placed in
# /usr/share/ for this script. 
# 
# Now I have a base image and store it's definition in the following:
# 
#  /var/lib/libvirt/images/base-image.qcow2
#  /usr/share/virsh-templates/base.xml

