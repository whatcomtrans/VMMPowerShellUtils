function New-VMFromTemplate {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="HostName")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="Name of the Virtual Machine to create.")]
		    [String]$NewVMName,
    	[Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$true,HelpMessage="Template name")]
		    [String] $VMTemplateName,
    	[Parameter(Mandatory=$true,ParameterSetName="HostName",HelpMessage="VMHost to create VM on")]
		    [String]$VMHostName
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

		$JobVariable = "theJob"

        $virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $VMTemplateName -Name $NewVMName

        Write-Verbose $virtualMachineConfiguration
        $vmHost = Get-SCVMHost -ComputerName $VMHostName

        Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $vmHost -ComputerName $NewVMName
        
        $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
        
        Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -PinDestinationLocation $false -FileName "$($NewVMName)_C.vhdx" -DeploymentOption "UseNetwork"
        
        Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration

        New-SCVirtualMachine -Name $NewVMName -VMConfiguration $virtualMachineConfiguration -Description "" -BlockDynamicOptimization $false -StartVM -JobGroup $GUID -ReturnImmediately -StartAction "AlwaysAutoTurnOnVM" -StopAction "SaveVM" -JobVariable $JobVariable
    
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

<#
.SYNOPSIS
Rebuild VMTemplates based on Hardware Profiles and Guest OS Profiles in a consistent fasion.  This is used when "stand alone" profiles
are updated.

#>
function Rebuild-VMTemplates {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,HelpMessage="Provide the name of a VHD stored in the library")]
		[Microsoft.SystemCenter.VirtualMachineManager.StandaloneVirtualHardDisk]$VHDObject
	)
	Begin {
        $JobGUID = [System.Guid]::NewGuid()
	}
	Process {
        forEach ($HWProfile in (Get-SCHardwareProfile)) {
            forEach ($OSProfile in (Get-SCGuestOSProfile)) {
                $TemplateName = $OSProfile.Name + "_" + $HWProfile.Name
                Echo $TemplateName
                if (Get-SCVMTemplate -Name $TemplateName) {
                    #Delete first
                    Get-SCVMTemplate -Name $TemplateName | Remove-SCVMTemplate -Force -RunAsynchronously
                }
                New-SCVMTemplate -VirtualHardDisk $VHDObject -Generation 1 -Name $TemplateName -HardwareProfile $HWProfile -GuestOSProfile $OSProfile -JobGroup $jobGUID
            }
        }
	}
	End {
        #Put end here
	}
}


Export-ModuleMember -Function "New-VMFromTemplate", "Rebuild-VMTemplates"
