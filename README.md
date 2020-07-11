# Azure-Resize
This script is to be used in conjunction with an Azure Automation account.  It will change the size of a VM based on tags applied to a server.

## Requirements
- Azure Automation Account on Subscription
- Az.Resources Module installed
- Az.Compute Module installed

## Usage
When the script runs it searches for all VM resources with the "Resize" tag applied to it.  The "Resize" tag should have a value set to an available VM size. 

Ex: "Resize" : "Standard_DS4_v2"
