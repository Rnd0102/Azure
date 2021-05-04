<#
.SYNOPSIS
Mengexport Database Azure SQL ke Container Blob Storage
.DESCRIPTION
Ini adalah  runbook script Powershell Wrokflow untuk mengexport Azure SQL Database ke Container Blob STorage dengan menginput beberapa parameter.

.PARAMETER ServerName
Nama SqlServer

.PARAMETER DatabaseName
Nama database

.PARAMETER ResourceGroupName
Nama resource group

.PARAMETER $ServerAdmin
Nama User

.PARAMETER $serverPassword
Password user

.PARAMETER $BaseStorageUri
Alamat Storage, Contoh isi : https://STORAGE-NAME.blob.core.windows.net/BLOB-CONTAINER-NAME/

.PARAMETER $StorageKey
Access key "YOUR STORAGE KEY" lihat di storage account --> settings --> select Access Keys --> Copy/Paste key1

.PARAMETER $FolderName
Nama folder container

#>
# ---- Login to Azure ----
workflow ExportAzureDB {



param
(
# Resource Group Name
[parameter(Mandatory=$true)]
[string] $ResourceGroupName,

# Name of the Azure SQL Database server
[parameter(Mandatory=$true)]
[string] $ServerName,

# Source Azure SQL Database name
[parameter(Mandatory=$true)]
[string] $DatabaseName,

# Source Azure SQL Username Admin
[parameter(Mandatory=$true)]
[string] $serverAdmin,

# Source Azure SQL Password Admin
[parameter(Mandatory=$true)]
[string] $serverPassword,

# Url Storage Account Blob
[parameter(Mandatory=$true)]
[string] $BaseStorageUri,

# Access Key Storage Account
[parameter(Mandatory=$true)]
[string] $StorageKey,

# Container Folder
[parameter(Mandatory=$true)]
[string] $FolderName

)

inlineScript
{
$connectionName = "AzureRunAsConnection"
try
{

# Get the connection "AzureRunAsConnection "
$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName
"Login to Azure"
Add-AzureRmAccount `
-ServicePrincipal `
-TenantId $servicePrincipalConnection.TenantId `
-ApplicationId $servicePrincipalConnection.ApplicationId `
-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
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

# convert server admin password to secure string
$securePassword = ConvertTo-SecureString -String $Using:serverPassword -AsPlainText -Force
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Using:serverAdmin, $securePassword

# Generate a unique filename for the BACPAC
$bacpacFilename = "$Using:DatabaseName" + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"

# Storage account info for the BACPAC
$BacpacUri = $Using:BaseStorageUri + "/$Using:FolderName/" + $bacpacFilename
$StorageKeytype = "StorageAccessKey"

#Menjalankan Proses Export
$exportRequest = New-AzureRmSqlDatabaseExport -ResourceGroupName "$Using:ResourceGroupName" -ServerName "$Using:ServerName" `
-DatabaseName "$Using:DatabaseName" -StorageKeytype $StorageKeytype -StorageKey $Using:StorageKey -StorageUri "$BacpacUri" `
-AdministratorLogin $creds.UserName -AdministratorLoginPassword $creds.Password

# Check status export
$exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
[Console]::Write("Exporting")
while ($exportStatus.Status -eq "InProgress")
{
$exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
Start-Sleep -s 10
}
$exportStatus
$Status= $exportStatus.Status
if($Status -eq "Succeeded")
{
Write-Output "Azure SQL DB Export $Status for "$Using:DatabaseName""
}
else
{
Write-Output "Azure SQL DB Export Failed for "$Using:DatabaseName""
}
}
}
