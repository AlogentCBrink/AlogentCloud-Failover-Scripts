################################################################################
#
# Gets information that is needed to be checked after a failover, returning the
#   information as a string.
#
#   1 ) Network AdaptorName    
#   2 ) IP Address      
#   3 ) Default Gateway 
#   4 ) DNS Servers     
#   5 ) DNS Suffix     
#
#   6 ) Domain Firewall Enabled
#   7 ) Private Firewall Enabled  
#   8 ) Public Firewall Enabled  
#
#   9 ) Server DateTime 
#
# Online Resources:
#
# Coded By:
#	Chris Brinkley
#
# Version:
#	1.0.0 	- 11/09/2020 -	Initial Build.
#
################################################################################
$NetAdapterList = (Get-CimInstance -Query "SELECT * FROM Win32_NetworkAdapter")
$NetAdapterConfigList = (Get-CimInstance -Query "SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = 'True'")

$Results = @()

foreach ($NetAdapter in $NetAdapterList){

    $NetAdapterConfig = $NetAdapterConfigList | Where-Object { $_.Index -eq $NetAdapter.DeviceID } 
    If ($NetAdapterConfig -ne $null -And $NetAdapter.Name -inotmatch "Virtual")
    {
        $Object = New-Object PSCustomObject

        $Object | Add-Member -MemberType NoteProperty -Name "AdaptorName" -Value $NetAdapter.Name -Force
        $Object | Add-Member -MemberType NoteProperty -Name "IPAddress" -Value $NetAdapterConfig.IPAddress -Force
        $Object | Add-Member -MemberType NoteProperty -Name "DefaultGateway" -Value $NetAdapterConfig.DefaultIPGateway -Force
        $Object | Add-Member -MemberType NoteProperty -Name "DNSServers" -Value $NetAdapterConfig.DNSServerSearchOrder -Force
        $Object | Add-Member -MemberType NoteProperty -Name "DNSSuffix" -Value $NetAdapterConfig.DNSDomainSuffixSearchOrder -Force


        $Results += $Object
    }
}

$fwInfo = Get-NetFirewallProfile | Select-Object Name, Enabled
$dateInfo = Get-Date | Select-Object DateTime

# Output Report
$output = "==========`n"
$output += "IP Info:"
$output += Out-String -InputObject $Results
$output += "Firewall Info:"
$output += Out-String -InputObject $fwInfo
$output += Out-String -InputObject $dateInfo
$output += "=========="

$output