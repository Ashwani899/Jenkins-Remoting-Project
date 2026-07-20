# Bootstraps a JNLP (inbound) Jenkins agent on Windows.
# Used this on agent-win-01, an old Windows 10 laptop - see docs/setup-agent-jnlp.md.
#
# Run from an elevated PowerShell prompt:
#   .\install-agent-windows.ps1 -ControllerUrl "http://192.168.1.50:8080" `
#       -AgentName "agent-win-01" -AgentSecret "xxxx"
#
# Note: for the actual persistent Windows service, I ended up using the
# "Install as a Windows service" installer offered directly on the node's
# page in a browser on this machine (http://<controller>/computer/<name>/)
# rather than wrapping this script - it's less fiddly than NSSM. This script
# is mainly useful for the first manual test connection.

param(
    [Parameter(Mandatory = $true)]
    [string]$ControllerUrl,

    [Parameter(Mandatory = $true)]
    [string]$AgentName,

    [Parameter(Mandatory = $true)]
    [string]$AgentSecret,

    [string]$WorkDir = "C:\jenkins-agent"
)

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Error "Java not found on PATH. Install Temurin 17 first: https://adoptium.net/"
    exit 1
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Set-Location $WorkDir

Write-Host "Downloading agent.jar from $ControllerUrl ..."
Invoke-WebRequest -Uri "$ControllerUrl/jnlpJars/agent.jar" -OutFile "$WorkDir\agent.jar"

Write-Host "Connecting as $AgentName ..."
java -jar "$WorkDir\agent.jar" `
    -url "$ControllerUrl/" `
    -secret $AgentSecret `
    -name $AgentName `
    -webSocket `
    -workDir $WorkDir
