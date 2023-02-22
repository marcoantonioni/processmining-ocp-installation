# Install IBM Process Mining v1.13.2 in OpenShift cluster


## Introduction

This document is a guide for making a demo installation (starter deployment) of IBM Process Mining v1.13.2 in an OpenShift cluster.
The example shown was tested in the IBM TechZone environment.

## Prerequisites

OpenShift ver. 4.8 or higher
At least 3 worker nodes (16core/32Gb)
A storage class of type RWX (minimum 30Gb disk)
A linux box with bash shell and OC CLI installed

## Process Mining version

The IBM PM version referenced by the scripts is 1.13.2.
This version requires a specific version (3.22.0) of "IBM Cloud Pak foundational services".
Installing IBM PM 1.13.2 in a pre-installed CP4BA v22.0.x environment fails due to incompatibility with the prerequisite version (3.23.0) of the CP4BA.
Currently and for this release it is required to use an OCP cluster with no other IBM Cloud Paks.

## Installation

In the case of IBM TechZone, request a new OCP cluster of the "Red Hat OpenShift on IBM Cloud (ROKS) v4.10 for Cloud Pak for Business Automation" or higher version at the link https://techzone.ibm.com/resource/reserve-here-cloud-pak-for-business-automation-open-shift-demo-environments#tab-2
Once the cluster is ready, log in and acquire the login command via token.
 
 
Login to the cluster from ssh terminal
Common and foundation services will be installed in the "ibm-common-services" namespace
Each Process Mining instance will be installed in its own namespace.
To use multiple instances of PM use different namespaces dedicated to the single instance.

For installation set the following environment variable with your token acquired at the link https://myibm.ibm.com/products-services/containerlibrary

export CP4BA_AUTO_ENTITLEMENT_KEY=" eyJ0eXAiOiJKV...your token...cuJjD5zY9Q"

Set the 3 environment variables (namespace values to your liking, the storage class must offer the RWX type)

export NS_CS=ibm-common-services
export PM_NAMESPACE=pm
export SC_NAME=managed-nfs-storage

run the script and wait for the installation to complete.

./install-pm.sh ${NS_CS} ${PM_NAMESPACE} ${SC_NAME}


Post installation checks

Log in to the URLs listed at the end of the install command.

References

Links for installation and configuration

IBM Cloud Pak foundational services v3.22
https://www.ibm.com/docs/en/cpfs?topic=322-installing-foundational-services-by-using-cli

IBM Process Mining 1.13.2
https://www.ibm.com/docs/en/process-mining/1.13.2?topic=configuration-online-installation

Link for PM administration
https://www.ibm.com/docs/en/process-mining/1.13.2?topic=environments-accessing-process-mining-user-interface