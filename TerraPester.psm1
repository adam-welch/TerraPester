function Invoke-TerraformInitAndPlan {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [object]$TerraformOptions,
    [string] $BasePath = $null
  )

  # Set scriptBase
  $scriptBase = $BasePath
  if([string]::IsNullOrEmpty($scriptBase)){
    $scriptBase = $MyInvocation.PSScriptRoot
  }

  $planFile = $TerraformOptions.PlanFileName
  if([string]::IsNullOrEmpty($planFile))
  {
    $planFile = "tf.plan"
  }

  $jsonFile = $TerraformOptions.JsonFileName
  if([string]::IsNullOrEmpty($jsonFile))
  {
    $jsonFile = "tfplan.json"
  }
  
  if([string]::IsNullOrEmpty($TerraformOptions.TerraformDir)){
    throw "Terraform Directory not supplied!"
  }

  $terraformPath = Resolve-Path $TerraformOptions.TerraformDir -ErrorAction SilentlyContinue

  # Check if fullpath was specified by resolving the path and testing it exists
  if(-not(Test-Path $terraformPath)){
    # the resolved path doesn't exist so try resolving relative to the path of the calling script
    $terraformPath = Resolve-Path $TerraformOptions.TerraformDir -RelativeBasePath $scriptBase -ErrorAction SilentlyContinue
    if(-not(Test-Path $terraformPath)){
      throw "Unable to find terraform directory: '$($TerraformOptions.TerraformDir)'."
    }
  }  


  # if(-not (Test-Path -Path $TerraformOptions.TerraformDir -PathType Container))
  # {
  #   throw "Terraform Directory not found!"
  # }

  $currentDir = Get-Location
  Push-Location $currentDir
  Set-Location $terraformPath

  try {

    $terraformCommand = "terraform init"
    Invoke-Expression $terraformCommand

    if ($LASTEXITCODE -ne 0) {
      Write-Error "Terraform init failed."
    }

    $terraformCommand = "terraform -chdir=`"{0}`" plan -out=`"$planFile`"" -f (Get-Location)

    # append any var args
    if($TerraformOptions.Vars.Length -gt 0) {
      foreach ($key in $TerraformOptions.Vars.Keys) {
        $value = $TerraformOptions.Vars[$key]
        $terraformCommand += " -var `"$key=$value`""
      }
    }

    # appends any var-file args
    if($TerraformOptions.VarFiles.Length -gt 0) {      
      foreach ($val in $TerraformOptions.VarFiles) {

        $varFilePath = Resolve-Path $val -ErrorAction SilentlyContinue

        # Check if fullpath was specified by resolving the path and testing it exists
        if(-not(Test-Path $varFilePath)){
          # the resolved path doesn't exist so try resolving relative to the path of the calling script
          $varFilePath = Resolve-Path $val -RelativeBasePath $scriptBase -ErrorAction SilentlyContinue
          if(-not(Test-Path $varFilePath)){
            throw "Unable to find terraform directory: '$val'."
          }
        }  

        $terraformCommand += " -var-file=`"$varFilePath`""
      }
    }

    Invoke-Expression $terraformCommand    

    if ($LASTEXITCODE -ne 0) {
      Write-Error "Terraform plan failed."
    }

    #### Convert plan file to json ####
    $jsonFilePath = Join-Path (Get-Location) $jsonFile
    $terraformCommand = "terraform -chdir=`"{0}`" show -json `"$planFile`""  -f (Get-Location)         
    Invoke-Expression $terraformCommand | Out-File -FilePath $jsonFilePath
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Converting plan to json failed."
    }
  } 
  catch 
  {
    if ($Error.Count -gt 0) {
      Write-Output $Error[0].ToString()
    }
  }
  Pop-Location 
}

function Invoke-PesterTests {

  Param(
    [Parameter(Mandatory=$true)]
    [object]$TerraformOptions,    
    [Parameter(Mandatory = $true)]
    [string] $TestFixtures,
    [string] $BasePath = $null
  )

  # Set the scriptBase
  $scriptBase = $BasePath
  if([string]::IsNullOrEmpty($scriptBase)){
    $scriptBase = $MyInvocation.PSScriptRoot
  }

  $fixturesPath = Resolve-Path $TestFixtures -ErrorAction SilentlyContinue
  # Check if fullpath was specified by resolving the path and testing it exists
  if(-not(Test-Path $fixturesPath -ErrorAction SilentlyContinue)){
    
    # the resolved path doesn't exist so try resolving relative to the path of the calling script
    $fixturesPath = Resolve-Path $TestFixtures -RelativeBasePath $scriptBase -ErrorAction SilentlyContinue
    if(-not(Test-Path $fixturesPath)){
      throw "Unable to find test folder '$TestFixtures'."
    }
  }

  $currentDir = Get-Location
  Push-Location $currentDir
  Set-Location $scriptBase

  try {
    
    # Check that Pester module is imported
    if (-not (Get-Module "Pester")) {
      Import-Module Pester
    }
  
    # Run the plan
    # Note, as running from a module the path of the calling script is used for the BasePath.. 
    # if executing the function direct this wouldn't be necessary as it would use the $MyInvocation.PSScriptRoot as the BasePath
    Invoke-TerraformInitAndPlan -TerraformOptions $TerraformOptions -BasePath $scriptBase

    # 
    $configuration = [PesterConfiguration] @{
      Run    = @{ Path = $fixturesPath; PassThru = $true }
      Output = @{ Verbosity = "Detailed"; RenderMode = "Plaintext" }
    }

    # Switch ErrorActionPreference to Stop temporary to make sure that tests will fail on silent errors too
    $backupErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    $results = Invoke-Pester -Configuration $configuration
    $ErrorActionPreference = $backupErrorActionPreference
    
    # Fail in case if no tests are run
    if (-not ($results -and ($results.FailedCount -eq 0) -and (($results.PassedCount + $results.SkippedCount) -gt 0))) {
      $results
      throw "Test run has failed"
    }
  }
  catch {
    if ($Error.Count -gt 0) {
      Write-Output $Error[0].ToString()
    }
  }
  Pop-Location 
}

Export-ModuleMember -Function Invoke-TerraformInitAndPlan, Invoke-PesterTests