#!/usr/bin/env bash
# Filename:                mkbase.sh
# Description:             How the base image was made
# Time-stamp:              <2018-02-17 14:01:34 fultonj> 
# -------------------------------------------------------
# CentOS-7-x86_64-GenericCloud.qcow2 was downloaded from:
#   https://cloud.centos.org/centos/7/images
# -------------------------------------------------------
if [[ ! -e base.qcow2 ]] ; then
    if [[ ! -e /nas/CentOS-7-x86_64-GenericCloud.qcow2 ]]; then
	echo "fail: base.qcow2 is missing"
	exit 1
    fi
    cp /nas/CentOS-7-x86_64-GenericCloud.qcow2 base.qcow2
fi

virt-customize -a base.qcow2 --run-command 'echo -e "d\nn\n\n\n\n\nw\n" | fdisk /dev/sda'
virt-customize -a base.qcow2 --run-command 'xfs_growfs /'
virt-filesystems --long -h --all -a base.qcow2
virt-customize -a base.qcow2 --run-command 'yum remove cloud-init* -y' 
virt-customize -a base.qcow2 --root-password password:fluffy

mv base.qcow2 /var/lib/libvirt/images/base.qcow2

# workaround "failed to initialize KVM: Permission denied"
sed -i s/\#group\ \=\ "root"/group\ \=\ \"wheel\"/g /etc/libvirt/qemu.conf
rmmod kvm_intel
rmmod kvm
modprobe kvm
modprobe kvm_intel

virt-install --cpu host --ram 2048 --vcpus 2 --os-variant rhel7 --disk path=/var/lib/libvirt/images/base.qcow2,device=disk,bus=virtio,format=qcow2 --import --noautoconsole --vnc --network network:default --name base 

sleep 30

virsh list --all
virsh shutdown base
virsh list --all

if [[ ! -d /usr/share/virsh-templates/ ]]; then
  mkdir /usr/share/virsh-templates/
fi

cp /etc/libvirt/qemu/base.xml /usr/share/virsh-templates/diff.xml
sed -i '/uuid/d' /usr/share/virsh-templates/diff.xml
sed -i s/\<name\>base\<\\/name\>/\<name\>diff\<\\/name\>/g /usr/share/virsh-templates/diff.xml

echo "The following now exist from which to derive diffs:"
ls -l /var/lib/libvirt/images/base.qcow2
ls -l /usr/share/virsh-templates/base.xml
