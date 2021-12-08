Param(
    [string]$TenantId = "",

    [Parameter(Mandatory = $false)]
    [string]$ProjectID = "",

    [Parameter(Mandatory = $false)]
    [string]$ProjectCodeName = "Psyduck",

    [Parameter(Mandatory = $false)]
    [string]$InformationOwner = "",

    [Parameter(Mandatory = $false)]
    [string]$ProjectResourceIdentifier = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "uat", "prod")]
    [string]$Environment = "dev",

    [ValidateSet("eastus", "eastus2", "centralus", "uksouth", "ukwest", "japaneast", "japanwest", "eastasia")]
    [string]$ResourceGroupLocation = "eastus2",

    [string] $departmentTag = "",

    [string] $budgetOwnerTag = "",

    [string] $productTag = "",

    [string]$ArtifactStorageContainerName = "storageartifacts",

    [string]$artifactStagingDirectory = ".",

    [Hashtable]$templateParameters = @{ }
)

# Setup options and variables
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
. .\Scripts\referenceFunctions.ps1

$tags = @{
    "Project ID"        = $ProjectID
    "Project Code Name" = $ProjectCodeName
    "Information Owner" = $InformationOwner
    "Budget Owner"      = $budgetOwnerTag
    "Department"        = $departmentTag
    "Product"           = $productTag
    "Environment"       = $Environment
}

# Build Resource Group and Artifacts Storage Account Names

$ResourceGroupName = Build-ResourceGroupName

$artifactStorageResourceGroupName = $ResourceGroupName
$ArtifactStorageAccountName = Build-ResourceName 1 "STA" "arts" -lowerCase

$ArtifactsStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactsStagingDirectory))

# Create Resource Group and Artifact Storage Account

Write-Host "`nStep1: Creating resource group $ArtifactsStorageResourceGroupName and artifact storage account $ArtifactStorageAccountName" -ForegroundColor Green

New-AzResourceGroup -Name $artifactStorageResourceGroupName -Location $ResourceGroupLocation -Tag $tags -Verbose -Force -ErrorAction Stop

try {
    .\Scripts\Create-ArtifactsStorageAccount.ps1 `
        -ResourceGroupName $artifactStorageResourceGroupName `
        -ResourceGroupLocation $ResourceGroupLocation `
        -StorageAccountName $ArtifactStorageAccountName
}
catch {
    throw $_
}

# Build Resource Names
$diagnosticStorageName = Build-ResourceName 1 "STA" "diag1" -lowerCase
$namespacesalixeventhub = Build-ResourceName 1 "EVH" "evh" -lowerCase
$blobStorageName = Build-ResourceName 1 "STB" "blob" -lowerCase

# Deploy main ARM template
Write-Host "`nStep 2: Deploying main resource template" -ForegroundColor Green
try {
    

    $templateParameters["diagnosticStorageName"] = $diagnosticStorageName
    $templateParameters["namespacesalixeventhub"] = $namespacesalixeventhub
    $templateParameters["blobStorageName"] = $blobStorageName
 
    $TemplateFilePath = [System.IO.Path]::Combine($ArtifactsStagingDirectory, ".\Artifacts\azuredeploy.json")
 
    Write-Host ($templateParameters | Out-String)

    $deploymentResults = .\Deploy-AzureResourceGroup.ps1 `
        -UploadArtifacts `
        -ResourceGroupLocation $ResourceGroupLocation `
        -ResourceGroupName $artifactStorageResourceGroupName `
        -StorageAccountName $ArtifactStorageAccountName `
        -ArtifactStagingDirectory $artifactStagingDirectory `
        -TemplateParameters $templateParameters `
        -TemplateFile $TemplateFilePath `
        -Tags $tags 

}
catch {
    throw $_
}

# Clean-up the artifacts storage account
Write-Host "`nStep 3: Removing the Artifacts Storage Account used for deployment..." -ForegroundColor Green
Remove-AzStorageAccount -ResourceGroupName $artifactStorageResourceGroupName -Name $ArtifactStorageAccountName -Force
