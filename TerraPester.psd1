@{
  ModuleVersion = '1.0.0'
  GUID = '482d2a6e-f171-4cff-b51e-47ecbf9fab69'
  Author = 'Adam Welch'
  CompanyName = 'Adam Welch'
  Copyright = 'Copyright (c) 2023 Adam Welch'
  Description = 'A module for running Terraform and Pester tests.'
  PowerShellVersion = '5.1'
  CompatiblePSEditions = @('Core', 'Desktop')
  FunctionsToExport = @('Set-EnvVariablesFromFile', 'Clear-EnvVariablesFromFile','Invoke-TerraformInitAndPlan', 'Invoke-PesterTests')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  ModuleList = @()
  FileList = @()
  PrivateData = @{}
  RequiredModules = @()
  RootModule = 'TerraPester.psm1'
}