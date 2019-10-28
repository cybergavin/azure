#!/bin/bash
# mrkips - create an Azure image from a VM using the Azure CLI
#
##################################################################################
#
# Variables
#
my_rg="mrkips-rg-cc-demo"
my_vm="mrkips-demo-cc-01"
my_img="mrkips-img-cc-01"
#
# STEP 1 : Create VM and build as needed
# STEP 2 : Deprovision user
# STEP 3 : Shutdown VM (Stop in Azure Portal)
# STEP 4 : Generalize the VM
az vm generalize --resource-group $my_rg --name $my_vm
# STEP 5 : Create an image
az image create --resource-group $my_rg --name $my_img --source $my_vm