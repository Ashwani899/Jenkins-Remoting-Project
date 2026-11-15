# Bootstraps a JNLP (inbound) Jenkins agent on Windows.
# See setup-agent-jnlp.md for the supported workflow and security notes.
#
# HTTPS is required by default. -AllowInsecureHttp is only for an isolated,
# trusted lab network. The Jenkins agent CLI receives -AgentSecret as a process
# argument, so run this only on a host where local process inspection is trusted.

param(
    [Parameter(Mandatory = $true)]
    [string]$ControllerUrl,

    [Parameter(Mandatory = $true)]
    [string]$AgentName,

    [Parameter(Mandatory = $true)]
    [string]$AgentSecret,

    [string]$WorkDir = "C:\\jenkins-agent",

    [switch]$AllowInsecureHttp
)

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    throw "Java not found on PATH. Install Temurin 17 first: https://adoptium.net/"
}

try {
    $controllerUri = [Uri]$ControllerUrl
} catch {
    throw "ControllerUrl must be an absolute HTTPS URL."
}

if (-not $controllerUri.IsAbsoluteUri -or $controllerUri.UserInfo) {
    throw "ControllerUrl must be an absolute URL without embedded credentials."
}

if ($controllerUri.Scheme -ne "https" -and
    -not ($AllowInsecureHttp -and $controllerUri.Scheme -eq "http")) {
    throw "HTTPS is required. Use -AllowInsecureHttp only on an isolated, trusted lab network."
}

if ($AgentName -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]*$") {
    throw "AgentName may contain only letters, digits, dot, underscore, and hyphen."
}

$ControllerUrl = $controllerUri.AbsoluteUri.TrimEnd("/")
if ($controllerUri.Scheme -eq "http") {
    Write-Warning "HTTP exposes the agent secret to network observers. Continue only on an isolated, trusted lab network."
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Set-Location $WorkDir

Write-Host "Downloading agent.jar from the configured controller..."
Invoke-WebRequest -Uri "$ControllerUrl/jnlpJars/agent.jar" -OutFile "$WorkDir\\agent.jar"

Write-Warning "The agent secret is passed to the Java process as a command-line argument. Restrict local access to this host."

Write-Host "Connecting as $AgentName ..."
& java -jar "$WorkDir\\agent.jar" `
    -url "$ControllerUrl/" `
    -secret $AgentSecret `
    -name $AgentName `
    -webSocket `
    -workDir $WorkDir

if ($LASTEXITCODE -ne 0) {
    throw "Jenkins agent exited with code $LASTEXITCODE."
}
