﻿param (
	[switch] $Quiet = $False
)
#region Default Private Variables
# Current script path
[string] $script:ScriptPath = Split-Path (Get-Variable MyInvocation -scope script).value.MyCommand.Definition -Parent
[string[]] $script:ShowHelp = @()
# if ($PSVersionTable.PSVersion.Major -lt 6) {
# 	[bool] $IsLinux = $false
# }
#endregion Default Private Variables

#region Load Private Helpers
# Dot sourcing private script files
Get-ChildItem $script:ScriptPath/private -Recurse -Filter "*.ps1" -File | ForEach-Object {
	. $_.FullName
}
#endregion Load Private Helpers

#region Load Public Helpers
# Dot sourcing public script files
Get-ChildItem $ScriptPath/public -Recurse -Filter "*.ps1" -File | ForEach-Object {
	. $_.FullName

	# From https://www.the-little-things.net/blog/2015/10/03/powershell-thoughts-on-module-design/
	# Find all the functions defined no deeper than the first level deep and export it.
	# This looks ugly but allows us to not keep any unneeded variables from polluting the module.
	([System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $_.FullName -Raw), [ref] $null, [ref] $null)).FindAll( { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object {
		#if (($IsLinux) -and ($_.Name -match 'SomethingThatMatches')) {
		#	#This Function is not available in Linux
		#} else {
		Export-ModuleMember $_.Name
		$ShowHelp += $_.Name
		#}
	}
}
#endregion Load Public Helpers

[pscredential] $script:uptCred = $null
[bool] $script:UseSecureToken = $false
$script:CurrentGroups = $null
$script:CurrentMembers = $null
$script:MaintenancePeriods = $null

try {
	if (-not (get-module -Name SecureTokens)) {
		Import-Module -Name SecureTokens -ErrorAction Stop -Force -ArgumentList $true
	} else {
		$script:UseSecureToken = $true
	}
} catch {
	Write-Status -Message 'Could not import the SecureTokens module.' -Type 'Error'
	Write-Status -Message 'SecureTokens will not be available' -Type 'Error' -Level 1
	$script:UseSecureToken = $false
}

#region Load Formats
if (test-path $ScriptPath\formats\brshUPTrends.format.ps1xml) {
	Update-FormatData $ScriptPath\formats\brshUPTrends.format.ps1xml
}
#endregion Load Formats

if (-not $Quiet) {
	Get-uptHelp
}

#region Module Cleanup
$ExecutionContext.SessionState.Module.OnRemove = {
	# cleanup when unloading module (if any)
	Get-ChildItem alias: | Where-Object { $_.Source -match "brshUPTrends" } | Remove-Item
	Get-ChildItem function: | Where-Object { $_.Source -match "brshUPTrends" } | Remove-Item
	Get-ChildItem variable: | Where-Object { $_.Source -match "brshUPTrends" } | Remove-Item
}
#endregion Module Cleanup

