function New-VMFromTemplate {
	[CmdletBinding(SupportsShouldProcess=$false,DefaultParameterSetName="HostName")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,HelpMessage="Name of the Virtual Machine to create.")]
		[String]$NewVMName,
    [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$true,HelpMessage="Template name")]
		[String] $VMTemplateName,
    [Parameter(Mandatory=$true,ParameterSetName="HostName",HelpMessage="VMHost to create VM on")]
		[String]$VMHostName,
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

        $virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $VMTemplateName -Name $NewVMName
        Write-Output $virtualMachineConfiguration
        $vmHost = Get-SCVMHost -ComputerName $VMHostName
        Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $vmHost -ComputerName $NewVMName
        $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
        Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -PinDestinationLocation $false -FileName "$($NewVMName)_C.vhdx" -DeploymentOption "UseNetwork"
        Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration

        $vmConfig = New-SCVirtualMachine -Name $NewVMName -VMConfiguration $virtualMachineConfiguration -Description "" -BlockDynamicOptimization $false -StartVM -JobGroup $GUID -ReturnImmediately -StartAction "AlwaysAutoTurnOnVM" -StopAction "SaveVM"
        return $vmConfig
	}
	End {
        #Put end here
	}
}


Export-ModuleMember -Function "New-VMFromTemplate"
