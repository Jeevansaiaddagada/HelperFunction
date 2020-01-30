Write-Output "Helper function calling"
<#
	TODO: Do we need the try/catch block ; @ line 103 & 136 for function Stop-AppPools and Start-AppPools
#>
function Retry-Command
{
    Param(
    [Parameter(Position=0, Mandatory=$true)]
    [scriptblock]$ScriptBlock,
    [Parameter(Position=1, Mandatory=$false)]
    [int]$Maximum = 40
    )
    Begin 
	{
        $cnt = 0
    }
    Process
	{
    	do
		{
			try
			{
            	$ScriptBlock.Invoke()
				return
            } 
			catch
			{
                Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
            }
			$cnt++
			Start-Sleep -Seconds 3
        } while ($cnt -lt $Maximum)
        throw 'Execution failed.  Could not successfully complete the command in 120 seconds.'
    }
}

function Get-VirtualDirectoryForWebsite($TargetPath)
{
	$Websites = Get-Website
    $allAppPools = @()
	foreach($Site in $Websites)
	{
	    $VDirs = Get-WebVirtualDirectory -Site $Site.name
		$allWebApplication = Get-WebApplication -Site $Site.name
		if ($Site.PhysicalPath -like "$TargetPath*")
		{
				$appPool = $Site.ApplicationPool
                $allAppPools += $appPool
		}
		
	    foreach($webvdirectory in $VDirs)
	    {
			$virtualDirectoryForWebsite = $webvdirectory.PhysicalPath
			if ($virtualDirectoryForWebsite -like "$TargetPath*")
			{
				$nameOfSite = $Site.Name
				$appPool = (Get-Website -Name $nameOfSite).ApplicationPool
                $allAppPools += $appPool
			}
	    } 
		
		foreach ($application in $allWebApplication)
		{
			if ($application.PhysicalPath -like "$TargetPath*")
			{
				$appPool = $application.ApplicationPool
                $allAppPools += $appPool
			}
		}
	}
    return $allAppPools
}

function Stop-AppPools($GetAllAppPools)
{
    foreach ($appPool in $GetAllAppPools)
    {
        $appPoolState = Get-WebAppPoolState -Name $appPool
        if ($appPoolState.value -ne 'Stopped')
        {
			Write-Output "Stopping AppPool - $appPool"
			Retry-Command -ScriptBlock {Stop-WebAppPool -Name $appPool}
        }
        else
        {
            Write-Output "AppPool - '$appPool' is already stopped."
        }

    }
}

function Start-AppPools($GetAllAppPools)
{
    foreach ($appPool in $GetAllAppPools)
    {
        $appPoolState = Get-WebAppPoolState -Name $appPool
        if ($appPoolState.value -ne 'Started')
        {
			Write-Output "Starting AppPool - $appPool"
			Retry-Command -ScriptBlock {Start-WebAppPool -Name $appPool}
        }
        else
        {
            Write-Output "AppPool - $appPool is already started"
        }
    }
}

function Copy-FilesToTarget($SourceLocation, $TargetLocation)
{
	robocopy /MT:4 /E /NDL /NC /NS /NFL /NP "$SourceLocation" "$TargetLocation"
	if ($LASTEXITCODE -lt 4) {
		Write-Output "Robocopy completed.  Exit code: $LASTEXITCODE"
	}
	else {
		throw "Copy failed as the exit code from robocopy was $LASTEXITCODE.  See robocopy logs for exact error."
	}
}


function Copy-WebConfigs($TargetFolder, $Environment)
{
	 # Copy the web config 
	 $getAllConfigs = Get-ChildItem "$targetFolder\*\Web.config" -Recurse
	 Write-Output "manipulating config files now"

	 foreach ($configItem in $getAllConfigs)
	 {
		 $actualDestination = $configItem.Directory.FullName
		 $actualDestination

		 if (Test-Path "$TargetFolder\config\$Environment")
		 {
			Copy-Item -Path "$actualDestination\config\$Environment" -Destination $actualDestination -Force
		 }

		 if (Test-Path "$actualDestination\bin\config")
		 {
			 Retry-Command -ScriptBlock {Remove-Item "$actualDestination\Web.Config" -Force}
			 Copy-Item -Path "$actualDestination\bin\config\*.config_$Environment" -Destination $actualDestination\web.config -Force
		


		 }
	 }
	
}

function Copy-WinServiceConfig($TargetFolder, $Environment)
{
	if (Test-Path "$TargetFolder\config")
    {
        Copy-Item -Path "$TargetFolder\config\*.config_$Environment" -Destination $TargetFolder -Force -WhatIf
        Copy-Item -Path "$TargetFolder\config\*.config_$Environment" -Destination $TargetFolder -Force
        Get-ChildItem "$TargetFolder\*.config_$Environment" |ForEach-Object {
    		$NewName = $_.Name -replace  "_$Environment", ''
    		$Destination = Join-Path -Path $_.Directory.FullName -ChildPath $NewName
    		Move-Item -Path $_.FullName -Destination $Destination -Force
    }
    }
}
