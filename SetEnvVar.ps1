[CmdletBinding()]
param([switch]$dotSourceOnly)

function Get-PSSessionOptions($ignoreCertificate){
    if($ignoreCertificate){
        $sessionOptions = (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)
    }else{
        $sessionOptions = (New-PSSessionOption)
    }

    return $sessionOptions
}

function Get-PSSession () {
    $machine = Get-VstsInput -Name "Machine" -Require
    $remoteUser = Get-VstsInput -Name "AdminUserName" -Require
    $remoteUserPass = Get-VstsInput -Name "AdminPassword" -Require
    $remoteProtocol = Get-VstsInput -Name "Protocol" -Require
    $useSSL = ($remoteProtocol -eq "Https")
    $ignoreCertificate = Get-VstsInput -Name "TestCertificate" -Require -AsBool
    # Open remote session.
    $secpasswd = ConvertTo-SecureString $remoteUserPass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($remoteUser, $secpasswd)
    $remoteSession = New-PSSession -ComputerName $machine -Credential $credential -UseSSL:$useSSL -SessionOption (Get-PSSessionOptions $ignoreCertificate)

    return $remoteSession
}

function Main () {
    # For more information on the VSTS Task SDK:
    # https://github.com/Microsoft/vsts-task-lib
    Trace-VstsEnteringInvocation $MyInvocation
    try {

        # Open winrm session.
        

        $environmentVariables = Get-VstsInput -Name "environment" -Require
        $environmentVarLevel = Get-VstsInput -Name "level" -Require
        $connectionType = Get-VstsInput -Name "ConnectionType" -Require

        if($connectionType -eq "Remote"){
            $remoteSession = Get-PSSession
        }

        if($environmentVariables){
            $environmentVariables -split "`n"| ForEach-Object {
                if($_.contains("=")){
                    $varName = ($_ -split "=")[0]
                    $varValue = $_.Replace("$varName=","")

                    if([string]::IsNullOrWhiteSpace($varValue)){
                        $varValue = $null
                    }

                    Write-Host "##[command] Name: $varName Value: $varValue Level: $environmentVarLevel"
                    if($connectionType -eq "Remote"){
                        Invoke-Command -Session $remoteSession -ArgumentList $varName, $varValue, $environmentVarLevel {
                            param($varName, $varValue, $level)
                            [Environment]::SetEnvironmentVariable($varName, $varValue, $level)
                        }
                    }else{
                        [Environment]::SetEnvironmentVariable($varName, $varValue, $level)
                    }
                }else{
                    Write-Host "Invalid format for var $_."
                }
            }
        }

    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

if($dotSourceOnly -eq $false){
    Main
}
