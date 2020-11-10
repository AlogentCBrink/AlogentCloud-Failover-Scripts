################################################################################
#
# Pushes a script to a listed server and runs that script, saving the output.
#
# You will be prompted for your domain credentials when the script starts.  They
#   must be entered with the doamin or your login will fail.
#
# You will be prompted for your local credentials for each of the workgroup 
#   computers listed.
#
# This script and the scipt to be pushed need to be in teh same directory.
#
# There will be 3 files created / updated durring the running of the script.
#   It these files do not exist they will be created int eh same directory as
#   the script is running in.  If they do exist they will be appended to.
#
#   1) Output.txt - This contains the results from the scripts running on the 
#       remote computers.
#   2) Completed-Computers.txt - This is a lsit of all the remote computers
#       that the script was successfully pushed to and run.
#   3) Unavailable-Computers.txt - This is a list of the remote computer that
#       returned an error on pushing or running the script.  The error is 
#       included.
#
# Online Resources:
#   https://www.tutorialspoint.com/explain-try-catch-finally-block-in-powershell
#
# Coded By:
#	Chris Brinkley
#
# Version:
#	1.0.0 	- 11/09/2020 -	Initial Build.
#
################################################################################
$ADComputers = @( "CAT-SQLFS01", "CAT-MFT01", "CAT-MFT02",                      # INF
                "CAT-Web01", "CAT-Web02", "CAT-App01", "CAT-App02", "CAT-App03",# IP
                "CAT-App-MFF01", "CAT-ECM-TN01",                                # ECM
                "CAT-App-AWARE01", "CAT-App-PG01", "CAT-APP-MTCA01",            # LFI
                "CAT-NXT-SPAGE"                                                 # Digital
)
$WGComputers = @( "CAT-MFTG01",                                                 # INF
                                                                                # IP
                "CAT-Web-EIM01",                                                # ECM
                "CAT-Web-LFI01", "CAT-Web-LFI02",                               # LFI
                "Web-AD-Demo"                                                   # Digital

)
$RemoteComputers = $ADComputers + $WGComputers + @("end")

$scriptPath = "Get-FailoverCheck.ps1"
$output = "==========`nStarting new report."
$output += Out-String -InputObject (Get-Date)
$output += "==========`n"

$adcreds = $host.ui.PromptForCredential("`nNeed credentials", "Please enter your AlogentCloud.local username and password INCLUDING DOMAIN!", "", "NetBiosUserName" )

write-host "`nStarting the push to Servers.`n"

ForEach ($Computer in $RemoteComputers) {
    Try {
        write-host $Computer
        if( $WGComputers -contains $Computer ) {
            $mycreds = $host.ui.PromptForCredential("`nNeed credentials", "Please enter your username and password for $Computer", "", "NetBiosUserName" )
        } else {
            $mycreds = $adcreds
        }
        
        $output += $Computer + "`n"
        $HstName = $Computer + ".alogentcloud.local"
        $ip = [System.Net.Dns]::GetHostAddresses($HstName)[0] 

        # Connect to Remote Computer
        $Session = New-PSSession -ComputerName $ip -Credential $mycreds
        
        # Copy Script to Remote Computer
        Copy-Item $scriptPath -Destination "C:\Alogent Software" -ToSession $Session
        
        # Run Script on Remote Comnputer
        $cOut = Invoke-Command -FilePath $scriptPath -ComputerName $ip -Credential $mycreds -ErrorAction Stop
        $output += Out-String -InputObject $cOut

        # Add to Completed List
        Add-Content Completed-Computers.txt $Computer
    }
    Catch {
        # There was an error connecting and running the script.  
        # Add to computer name to the error list and save the error 
        Add-Content Unavailable-Computers.txt $Computer
        if ($Computer -ne  @("end") ){
            $output += "  An Error Occured!`n==========`n"
            Add-Content Unavailable-Computers.txt $Error[0].Exception.Message 
            Add-Content Unavailable-Computers.txt $Error[1].Exception.Message 
        }
    }
}
Add-Content Completed-Computers.txt $Computer
Add-Content Output.txt $output

Write-Host "`nPush Complete!"
Write-Host "See Output.txt in this directory to see the results."