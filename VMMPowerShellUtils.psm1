function New-VMFromTemplate {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="HostName")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="Name of the Virtual Machine to create.")]
		[String]$NewVMName,
    [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$true,HelpMessage="Template name")]
		[String] $VMTemplateName,
    [Parameter(Mandatory=$true,ParameterSetName="HostName",HelpMessage="VMHost to create VM on")]
		[String]$VMHostName,
		[Parameter(Mandatory=$false,HelpMessage="The name of a variable to place the job info into, see New-SCVirtualMachine")]
		[String]$JobVariable
	)
	Begin {
        #Put begining stuff here
	}
	Process {
        [GUID] $GUID = [guid]::NewGuid().Guid

        if (!$VMTemplateName) {
            $VMTemplateName = (Get-Template | select Name | Out-GridView)
            if ($VMTemplateName -eq $null) {
                return $null
            }
        }

				if (!$JobVariable) {
					$JobVariable = "theJob"
				}

        $virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $VMTemplateName -Name $NewVMName
        Write-Output $virtualMachineConfiguration
        $vmHost = Get-SCVMHost -ComputerName $VMHostName
        Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $vmHost -ComputerName $NewVMName
        $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
        Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -PinDestinationLocation $false -FileName "$($NewVMName)_C.vhdx" -DeploymentOption "UseNetwork"
        Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration

        $vmConfig = New-SCVirtualMachine -Name $NewVMName -VMConfiguration $virtualMachineConfiguration -Description "" -BlockDynamicOptimization $false -StartVM -JobGroup $GUID -ReturnImmediately -StartAction "AlwaysAutoTurnOnVM" -StopAction "SaveVM" -JobVariable $JobVariable

				#If returning the JobVariable, create new variable with same name but in the parent scope
				if ($JobVariable -ne "theJob") {
					New-Variable -Name $JobVariable -Value (Get-Variable -Name $JobVariable) -Scope 1
				}

        return $vmConfig
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

	}
	End {
				#Put end here
	}
}

Export-ModuleMember -Function "New-VMFromTemplate"
