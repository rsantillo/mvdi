#!/usr/bin/env bash
# Filename:                hypervisor.sh
# Description:             configure centos as hypervisor
# Time-stamp:              <2018-02-17 12:03:04 fultonj> 
# -------------------------------------------------------
sudo yum install -y kvm libvirt libvirt-python python-virtinst libguestfs-tools
