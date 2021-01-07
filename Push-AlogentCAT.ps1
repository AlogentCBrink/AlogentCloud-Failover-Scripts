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
#   1.1.0   - 12/02/2020 -  Added Checking Servers from AD.
#                           Added Reading server list from a file.
#                           Started Proceduralizing code.
#                           Started Error handeling.
#	1.0.0 	- 11/09/2020 -	Initial Build.
#
################################################################################

################################################################################
#   Paramater Declaration(s)
################################################################################

[CmdletBinding()]
param(
#    [Parameter(Mandatory=$true)]
    [String]$ServerListFile = "test.csv",

    [String]$ScriptPath = "Get-FailoverCheck.ps1"

)

################################################################################
#   Check is RSAT is installed as it is now required.
################################################################################
if (-Not (Get-HotFix -id KB2693643 -ErrorAction SilentlyContinue)) {
    Write-Host "Remote Server Administration Tools are not installed.  This is required for the script to work." -BackgroundColor Red -ForegroundColor White
    Write-Host "Please install KB2693643." -BackgroundColor Red -ForegroundColor White
    Return      # End script if no RSAT
} 

################################################################################
#   Function Declaration(s)
################################################################################
function Get-ADComputerList([PSCredential] $creds){
    $computers = @{}

    Write-Host "Staring Domain computer lookup."

    try {
        $computers = Get-ADComputer -Filter * -SearchBase "DC=AlogentCloud,DC=local" -Server "prod-dc01.alogentcloud.local" -Credential $creds -ErrorAction Stop| Select-Object Name
    } catch {
        Write-Host "Unable to conenct to Prod-DC01 to get Server List."
        Write-Host $_.Exception.Message -ForegroundColor Red
        try {
            $computers = Get-ADComputer -Filter * -SearchBase "DC=AlogentCloud,DC=local" -Server "10.210.4.23" -Credential $creds -ErrorAction Stop | Select-Object Name
        } catch {
            Write-Host "Unable to conenct to Prod-DC03 to get Server List."
            Write-Host $_.Exception.Message -ForegroundColor Red    
        }
    }
    return $computers
}

function Get-ComputerList([String] $fileName, [Boolean] $testing = $false) {
    if ($testing) {
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
        $computerList = ($ADComputers + $WGComputers) | Sort-Object        
    } else {
        $computerList = Import-CSV $fileName
    }
    $computerList += @("end")

    Return $computerList
}

################################################################################
#   Variable Declaration(s)
################################################################################
$adCreds = @()
$domainComputers = @{}
$remoteComputers = @{}
$output = ""

################################################################################
#   Main Program
################################################################################
$adCreds = $host.ui.PromptForCredential("`nNeed credentials", 
    "Please enter your AlogentCloud.local username and password INCLUDING DOMAIN!", 
    "", "NetBiosUserName" )
$domainComputers = Get-ADComputerList $adCreds
if (-Not $domainComputers.count) {
    Write-Host "No servers were retrieved from the Domain Controler." -BackgroundColor Red -ForegroundColor White
    Write-Host "Exiting script." -BackgroundColor Red -ForegroundColor White
    Return      # End script if no Domain Computers
}
$remoteComputers = Get-ComputerList $ServerListFile

$output = Out-String -InputObject (Get-Date)
$output += "==========`n"

write-host "`nStarting the push to Servers.`n"

ForEach ($computer in $remoteComputers.Server_Name) {
    Try {
        if ($computer -ne @("end")) {    
            write-host "Connecting to: " $computer
            if( $domainComputers.Name -notcontains $computer.ToUpper() ) {
                $mycreds = $host.ui.PromptForCredential("`nNeed credentials", 
                    "Please enter your username and password for $computer", 
                    "", "NetBiosUserName" )
            } else {
                $mycreds = $adCreds
            }
            $output += $computer + "`n"
            $hstName = $computer + ".alogentcloud.local"
            $ip = [System.Net.Dns]::GetHostAddresses($hstName)[0] 

            # Connect to Remote computer
            $Session = New-PSSession -ComputerName $ip -Credential $mycreds
            
            # Copy Script to Remote computer
            Copy-Item $ScriptPath -Destination "C:\Alogent Software" -ToSession $Session
            
            # Run Script on Remote Comnputer
            $cOut = Invoke-Command -FilePath $ScriptPath -ComputerName $ip -Credential $mycreds -ErrorAction Stop
            $output += Out-String -InputObject $cOut
        
            # Add to Completed List
            Add-Content Completed-Computers.txt $computer
        }
    }
    Catch {
        # There was an error connecting and running the script.  
        # Add to computer name to the error list and save the error 
        Add-Content Unavailable-Computers.txt $computer
        if ($computer -ne  @("end") ){
            $output += "  An Error Occured!`n==========`n"
            Add-Content Unavailable-Computers.txt $Error[0].Exception.Message 
            Add-Content Unavailable-Computers.txt $Error[1].Exception.Message 
        }
    }
}
Add-Content Completed-Computers.txt $computer
Add-Content Output.txt $output

Write-Host "`nPush Complete!"
Write-Host "See Output.txt in this directory to see the results."