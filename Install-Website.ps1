# Get-HelperFunction.ps1 is called without dot-sourcing using LibraryScripts in Synthetic.xml
function Deploy-CdwApplication
{
	$targetFolders = $deployed.targetPath.split(";")
	$environment = $deployed.environment
    $filePath = $deployed.file

    foreach ($targetFolder in $targetFolders) {
        $getAllAppPools = Get-VirtualDirectoryForWebsite -TargetPath "$targetFolder"
        $getAllAppPools = $getAllAppPools | Select-Object -Unique
        
        Stop-AppPools -GetAllAppPools $getAllAppPools
        
        if (Test-Path $targetFolder)
        {
            Write-Host "$targetFolder exists"
            Write-Host "Removing '$targetfolder\*'"
            Retry-Command -ScriptBlock {Remove-Item "$targetFolder\*" -Recurse -Force }
        }
        else
        {
            New-Item -ItemType Directory -Path $targetFolder 
        }

        Copy-FilesToTarget $filePath $targetFolder

        # Copy the web config 
        # $getAllConfigs = Get-ChildItem "$targetFolder\*\Web.config" -Recurse
        # Write-Output "manipulating config files now"

        # foreach ($configItem in $getAllConfigs)
        # {
        #     $actualDestination = $configItem.Directory.FullName
        #     $actualDestination
        #     if (Test-Path "$actualDestination\bin\config")
        #     {
        #         Retry-Command -ScriptBlock {Remove-Item "$actualDestination\Web.Config" -Force}
        #         Copy-Item -Path "$actualDestination\bin\config\*.config_$environment" -Destination $actualDestination\web.config -Force
        #     }
        # }

        Copy-WebConfigs $targetFolder

        #For Monolith Configs
        if (Test-Path ("$targetFolder\Cdw.WebApp.Home\extra"))
        {
            $envToUse = $environment
            if ($envToUse.ToLower() -eq "dev") {$envToUse = "INTEGRATION"}
            if ($envToUse.ToLower() -eq "staging") {$envToUse = "STAGE"}
            if ($envToUse.ToLower() -eq "prod") {$envToUse = "PRODUCTION"}
            $siteType = "c"
            if ($targetFolder.contains("cdwg.com")) {$siteType = "g"}
            if ($targetFolder.contains("cdw.ca")) {$siteType = "ca"}

            Copy-FilesToTarget "$targetFolder\Cdw.WebApp.Home\extra\$envToUse\$siteType" "$targetFolder\Cdw.WebApp.Home"
        }

        Start-AppPools -GetAllAppPools $getAllAppPools
    }
}

Deploy-CdwApplication
exit 0