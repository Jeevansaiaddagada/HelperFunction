function Install-WindowsService
{
	$targetFolder = $deployed.targetPath
	$environment = $deployed.environment
    $filePath = $deployed.file
	$Tags = $deployed.tags
    $ServiceName = $deployed.servicename
    $deployedType = $deployed.type
    # $name = $deployed.container
    # $deployed.container
    Write-Output "name of container $name"
	Write-Output $targetFolder
	Write-Output $environment
	Write-Output "Tags are $Tags"
    Write-Output "ServiceName is $ServiceName"
    # $deployed.Deployment
    # $deployed
	try
	{
		$statusOfService = (Get-Service -Name $ServiceName).status
	}
	catch
	{
		Write-Error "not able to get the status fro Service - $ServiceName"
		Write-Error $_
		return
	}
		
    if ($statusOfService -eq "Running")
	{
		Write-Output "Stopping Windows Service -$ServiceName"
		Retry-Command -ScriptBlock {Stop-Service -Name $ServiceName}
		Start-Sleep -Seconds 10
	}
	elseif (($statusOfService -eq "Stopped") -or ($statusOfService -eq "disabled"))
	{
		Write-Output "Service - '$ServiceName' is $statusOfService before the deployment"
		
	}
	
	# Copy the files 
	
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

    #Copy-Item "$filePath\*" "$targetFolder\"  -Recurse -Force  -WhatIf
	Write-Output "Copying files from $filePath\* to $targetFolder\"
    Copy-Item "$filePath\*" "$targetFolder\"  -Recurse -Force    
	
    $getAllConfigs = Get-ChildItem "$targetFolder\*.config_$environment" -Recurse
    Write-Output "manipulating config files now"

    # if (Test-Path "$targetFolder\config")
    # {
    #     Copy-Item -Path "$targetFolder\config\*.config_$environment" -Destination $targetFolder -Force -WhatIf
    #     Copy-Item -Path "$targetFolder\config\*.config_$environment" -Destination $targetFolder -Force
    #     Get-ChildItem "$targetFolder\*.config_$environment" |ForEach-Object {
    # 		$NewName = $_.Name -replace  "_$environment", ''
    # 		$Destination = Join-Path -Path $_.Directory.FullName -ChildPath $NewName
    # 		Move-Item -Path $_.FullName -Destination $Destination -Force
    # }
	# }
	
	Copy-WinServiceConfig $TargetFolder $Environment 

    
	# Start the windows service
	try
	{
		Retry-Command -ScriptBlock {Start-Service -Name $ServiceName}
	}
	catch
	{
		Write-Error "Service - $ServiceName could not be started"
	}
}

Install-WindowsService
