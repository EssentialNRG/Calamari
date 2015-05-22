﻿## Octopus Azure deployment script, version 1.0
## --------------------------------------------------------------------------------------
##
## This script is used to control how we deploy packages to Windows Azure. 
##
## When the script is run, the correct Azure subscription will ALREADY be selected,
## and we'll have loaded the neccessary management certificates. The Azure PowerShell module
## will also be loaded.  
##
## If you want to customize the Azure deployment process, simply copy this script into
## your NuGet package as DeployToAzure.ps1. Octopus will invoke it instead of the default 
## script. 
## 
## The script will be passed the following parameters in addition to the normal Octopus 
## variables passed to any PowerShell script. 
## 
##   $OctopusAzureSubscriptionId           // The subscription ID GUID
##   $OctopusAzureSubscriptionName         // The random name of the temporary Azure subscription record
##   $OctopusAzureServiceName              // The name of your cloud service
##   $OctopusAzureStorageAccountName       // The name of your storage account
##   $OctopusAzureSlot                     // The name of the slot to deploy to (Staging or Production)
##   $OctopusAzurePackageUri               // URI to the .cspkg file in Azure Blob Storage to deploy 
##   $OctopusAzureConfigurationFile        // The name of the Azure cloud service configuration file to use
##   $OctopusAzureDeploymentLabel          // The label to use for deployment
##   $OctopusAzureSwapIfPossible           // "True" if we should attempt to "swap" deployments rather than a new deployment

function CreateOrUpdate() 
{
    $deployment = Get-AzureDeployment -ServiceName $OctopusAzureServiceName -Slot $OctopusAzureSlot -ErrorVariable a -ErrorAction silentlycontinue
 
    if (($a[0] -ne $null) -or ($deployment.Name -eq $null)) 
    {
        CreateNewDeployment
        return
    } 

    if (($OctopusAzureSwapIfPossible -eq $true) -and ($OctopusAzureSlot -eq "Production")) 
    {
        Write-Host "Checking whether a swap is possible"
        $staging = Get-AzureDeployment -ServiceName $OctopusAzureServiceName -Slot "Staging" -ErrorVariable a -ErrorAction silentlycontinue
        if (($a[0] -ne $null) -or ($staging.Name -eq $null)) 
        {
            Write-Host "Nothing is deployed in staging"
        }
        else 
        {
            Write-Host ("Current staging deployment: " + $staging.Label)
            if ($staging.Label -eq $OctopusAzureDeploymentLabel) {
                SwapDeployment
                return
            }
        }
    }
    
    UpdateDeployment
}
 
function SwapDeployment()
{
    Write-Host "Swapping the staging environment to production"
    Move-AzureDeployment -ServiceName $OctopusAzureServiceName
}
 
function UpdateDeployment()
{
    Write-Host "A deployment already exists in $OctopusAzureServiceName for slot $OctopusAzureSlot. Upgrading deployment..."
    Set-AzureDeployment -Upgrade -ServiceName $OctopusAzureServiceName -Package $OctopusAzurePackageUri -Configuration $OctopusAzureConfigurationFile -Slot $OctopusAzureSlot -Mode Auto -label $OctopusAzureDeploymentLabel -Force
}
 
function CreateNewDeployment()
{
    Write-Host "Creating a new deployment..."
    New-AzureDeployment -Slot $OctopusAzureSlot -Package $OctopusAzurePackageUri -Configuration $OctopusAzureConfigurationFile -label $OctopusAzureDeploymentLabel -ServiceName $OctopusAzureServiceName
}

function WaitForComplete() 
{
    $completeDeployment = Get-AzureDeployment -ServiceName $OctopusAzureServiceName -Slot $OctopusAzureSlot

    $completeDeploymentID = $completeDeployment.DeploymentId
    Write-Host "Deployment complete; Deployment ID: $completeDeploymentID"
}

CreateOrUpdate
WaitForComplete