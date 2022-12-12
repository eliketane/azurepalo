This is using terraform to create a hub and spoke topology with a server and palo firewall

Download vs code for the microsoft marketplace

Prerequisites
An Azure subscription. If you do not have an Azure account, create one now.

Terraform 0.14.9 or later

The Azure CLI Tool installed
############################
# Step One (Install)
# https://aka.ms/installazurecliwindows
# For other distros: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
############################

# Signing Into Azure
az interactive
az login
#az cloud list --output table (If connecting to specialized clouds)
#az cloud set --name AzureCloud

# Get Working Context
az account show

# Get All Subsriptions We Have Access To
az account list

# Set Working Context
az account set -subscription XXXX

install terraform

https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli

ensure that you have downloaded the add-ons for azure and terraform in VS code
