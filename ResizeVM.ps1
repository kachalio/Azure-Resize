
Import-Module Az.Resources
Import-Module Az.Compute

function Update-Tag {

    Param ( [string]$resourceId, [string]$tagKey, [string]$tagValue )
    $resource = Get-AzResource -ResourceId $resourceId
    $tagKeyArray = $resource.tags.keys

    #checking if the tag exists
    if ($tagKeyArray -match "$tagKey"){
        #update not create
        $resource.Tags["$tagKey"] = $tagValue
    }
    else{
        #create
        $resource.Tags.Add("$tagKey", "$tagValue")
        
    }
    Set-AzResource -Tag $resource.Tags -ResourceId $resource.Id -Force
}


$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "

    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

    "Logging in to Azure..."
    $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                             -ApplicationId $servicePrincipalConnection.ApplicationID   `
                             -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                             -ServicePrincipal
    "Logged in."

}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}


$resizeTagKey = "Resize"
$originalTagKey = "OriginalSize"
$sizeChangeDateKey = "SizeChangeDate"

$resources = Get-AzResource -TagName "Resize" -ResourceType "Microsoft.Compute/virtualMachines"

$resources | ForEach-Object {
    # This section gets some important info for our script
    # First it actually finds the VM resource based on the resource group name and resource name and returns a vm object
    # then we get the new size information and original size information
    # then we set the new size data and update the VM which causes reboot
    $vm = Get-AzVM -ResourceGroupName $_.ResourceGroupName -Name $_.Name

    $newSize = $vm.Tags["$resizeTagKey"]
    $originalSize = $vm.HardwareProfile.VmSize
    $availableSizes = (Get-AzVMSize -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name).Name
    $vmName = $vm.Name

    Write-Host $vmName

    #checking if the new size is the same as the current size
    if($newSize -eq $originalSize){
        Write-Output "$vmName- New size is the same as current size.  Skipping."
    }
    #checking to make sure the new size is available
    elseif($availableSizes -notcontains $newSize){
        "$vmName- $newSize is not a valid size for this VM, skipping.  Please use 'Get-AzVMSize -ResourceGroupName " + $vm.ResourceGroupName + "-VMName " + $vm.Name + "' to verify."
    }
    #changing size
    else{
        $vm.HardwareProfile.VmSize = "$newSize"
        $date = Get-Date
        Update-AzVM -ResourceGroupName $vm.ResourceGroupName -VM $vm
        Write-Output "$vmName resized to $newSize"

        Update-Tag -resourceId $vm.Id -tagKey $sizeChangeDateKey -tagValue $date
        Update-Tag -resourceId $vm.Id -tagKey $originalTagKey -tagValue $originalSize
        
           
    }
}

Write-Output "Complete"