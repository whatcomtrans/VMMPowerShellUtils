function New-VMFromTemplate {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="HostName")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="Name of the Virtual Machine to create.")]
		    [String]$NewVMName,
    	[Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$true,HelpMessage="Template name")]
		    [String] $VMTemplateName,
    	[Parameter(Mandatory=$true,ParameterSetName="HostName",HelpMessage="VMHost to create VM on")]
		    [String]$VMHostName,
        [Parameter(Mandatory=$false,HelpMessage="Return immediately (default) or wait for creation to finish.")]
            [Switch]$wait
	)
	Begin {
        #Put begining stuff here
	}
	Process {
        [GUID] $GUID = [guid]::NewGuid().Guid

        [Boolean] $returnImmediately = $true
        if ($wait) {$returnImmediately = $false}

        if (!$VMTemplateName) {
            $VMTemplateName = (Get-Template | select Name | Out-GridView)
            if ($VMTemplateName -eq $null) {
                return $null
            }
        }

		$JobVariable = "theJob"

        $virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $VMTemplateName -Name $NewVMName

        Write-Verbose $virtualMachineConfiguration
        $vmHost = Get-SCVMHost -ComputerName $VMHostName

        Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $vmHost -ComputerName $NewVMName
        
        $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
        
        Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -PinDestinationLocation $false -FileName "$($NewVMName)_C.vhdx" -DeploymentOption "UseNetwork"
        
        Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration

        New-SCVirtualMachine -Name $NewVMName -VMConfiguration $virtualMachineConfiguration -Description "" -BlockDynamicOptimization $false -StartVM -JobGroup $GUID -ReturnImmediately:$returnImmediately -StartAction "AlwaysAutoTurnOnVM" -StopAction "SaveVM" -JobVariable $JobVariable
    
    	#Set-SCVirtualMachine -VM $NewVMName -EnableTimeSync $false
	
        $result = New-Object -TypeName PSObject
        Add-Member -InputObject $result -MemberType NoteProperty -Name Config -Value $virtualMachineConfiguration
        Add-Member -InputObject $result -MemberType NoteProperty -Name Job -Value (Get-Variable -Name $JobVariable).Value

        return $result
	}
	End {
        #Put end here
	}
}

function Add-VMHardDisk {
	[CmdletBinding(SupportsShouldProcess=$false,DefaultParameterSetName="example")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ParameterSetName="example",HelpMessage="put help here")]
		[String]$VMName,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ParameterSetName="example",HelpMessage="put help here")]
		[String]$DiskName,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ParameterSetName="example",HelpMessage="put help here")]
		[UInt64]$SizeBytes
	)
	Begin {
				#Put begining stuff here
	}
	Process {
		#Get info from VM
		$vmInfo = Get-SCVirtualMachine $VMName # $vmInfo.Location $vmInfo.HostName

		#Create new VHD
		$diskPath = "$($vmInfo.Location)\$($DiskName)"
		New-VHD -ComputerName $vmInfo.HostName -Path $diskPath -SizeBytes $SizeBytes -Dynamic  #Should make dynamic/fixed as options...

		#Add the VHD to the VM
		Add-VMHardDisk -VMName $VMName -Path $diskPath
		
        #Mount, initalize, partition, and format the VHD from on the VM
        #TODO
	}
	End {
				#Put end here
	}
}

function New-wtaVMMVMTemplate {
	[CmdletBinding(SupportsShouldProcess=$false)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="Hardware profile to use")]
		 [String] $HardwareProfileName = "wtaP1R1domain",
        [Parameter(Mandatory=$false,HelpMessage="Disk image name to use, defaults to WTAWIN2012R2STD.vhdx")]
		 [String] $DiskName = "WTAWIN2012R2STD.vhdx",
        [Parameter(Mandatory=$false,HelpMessage="Guest OS profile to use, defaults to WIN2012R2-DOMAIN-DEFAULT")]
		 [String] $GuestOSProfileName = "WIN2012R2-DOMAIN-DEFAULT"
	)
	Process {
        #Put process here
        [Guid] $JobGroupGUID = ([guid]::NewGuid()).Guid

        if ($DiskName -eq "WTAWIN2012R2STD.vhdx") {
            [String] $Name = $GuestOSProfileName + "_" + $HardwareProfileName
        } else {
            [String] $Name = $GuestOSProfileName + "_" + $HardwareProfileName + "_" + $DiskName
        }
        [String] $Description = $Name

        $HardwareProfile = Get-SCHardwareProfile | where {$_.Name -eq $HardwareProfileName}
        $GuestOSProfile = Get-SCGuestOSProfile | where {$_.Name -eq $GuestOSProfileName}

        $OperatingSystem = Get-SCOperatingSystem | where {$_.Name -eq "Windows Server 2012 R2 Standard"}

        $VirtualHardDisk = Get-SCVirtualHardDisk | where HostType -EQ "LibraryServer" | where Name -like $DiskName
        if ($HardwareProfile.Generation -eq 1) {   #IDE
            New-SCVirtualDiskDrive -IDE -Bus 0 -LUN 0 -JobGroup $JobGroupGUID -CreateDiffDisk $false -VirtualHardDisk $VirtualHardDisk -VolumeType BootAndSystem
        } else {  #SCSI
            New-SCVirtualDiskDrive -SCSI -Bus 0 -LUN 1 -JobGroup $JobGroupGUID -CreateDiffDisk $false -VirtualHardDisk $VirtualHardDisk -VolumeType BootAndSystem
        }

        $template = New-SCVMTemplate -Name $Name -RunAsynchronously -Description $Description -Generation ($HardwareProfile.Generation) -HardwareProfile $HardwareProfile -GuestOSProfile $GuestOSProfile -JobGroup $JobGroupGUID -ComputerName "*" -TimeZone 4  -FullName "" -OrganizationName "" -AnswerFile $null -OperatingSystem $OperatingSystem 
        return $template
    }
}

Export-ModuleMember -Function "*"
