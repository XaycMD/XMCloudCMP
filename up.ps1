[CmdletBinding(DefaultParameterSetName = "no-arguments")]
Param (
    [Parameter(HelpMessage = "Toggles whether to skip building the images.",
        ParameterSetName = "skip-build")]
    [switch]$SkipBuild,

    [Parameter(HelpMessage = "Toggles whether to skip schemas and rebuild of the indexes.",
        ParameterSetName = "skip-indexing")]
    [switch]$SkipIndexing,

    [Parameter(HelpMessage = "Toggles whether to skip pushing items and JSS configuration.",
        ParameterSetName = "skip-push")]
    [switch]$SkipPush,

    [Parameter(HelpMessage = "Toggles whether to skip opening the site and CM in a browser.",
        ParameterSetName = "skip-open")]
    [switch]$SkipOpen
)

$ErrorActionPreference = "Stop";

$envPath = ".env.user"
$envContent = Get-Content $envPath -Encoding UTF8
$xmCloudHost = $envContent | Where-Object { $_ -imatch "^CM_HOST=.+" }
$sitecoreDockerRegistry = $envContent | Where-Object { $_ -imatch "^SITECORE_DOCKER_REGISTRY=.+" }
$sitecoreVersion = $envContent | Where-Object { $_ -imatch "^SITECORE_VERSION=.+" }
$ClientCredentialsLogin = $envContent | Where-Object { $_ -imatch "^SITECORE_FedAuth_dot_Auth0_dot_ClientCredentialsLogin=.+" }
$sitecoreApiKey = ($envContent | Where-Object { $_ -imatch "^SITECORE_API_KEY_xmcloudpreview=.+" }).Split("=")[1]

$xmCloudHost = $xmCloudHost.Split("=")[1]
$sitecoreDockerRegistry = $sitecoreDockerRegistry.Split("=")[1]
$sitecoreVersion = $sitecoreVersion.Split("=")[1]
$ClientCredentialsLogin = $ClientCredentialsLogin.Split("=")[1]
if ($ClientCredentialsLogin -eq "true") {
	$xmCloudClientCredentialsLoginDomain = $envContent | Where-Object { $_ -imatch "^SITECORE_FedAuth_dot_Auth0_dot_Domain=.+" }
	$xmCloudClientCredentialsLoginAudience = $envContent | Where-Object { $_ -imatch "^SITECORE_FedAuth_dot_Auth0_dot_ClientCredentialsLogin_Audience=.+" }
	$xmCloudClientCredentialsLoginClientId = $envContent | Where-Object { $_ -imatch "^SITECORE_FedAuth_dot_Auth0_dot_ClientCredentialsLogin_ClientId=.+" }
	$xmCloudClientCredentialsLoginClientSecret = $envContent | Where-Object { $_ -imatch "^SITECORE_FedAuth_dot_Auth0_dot_ClientCredentialsLogin_ClientSecret=.+" }
	$xmCloudClientCredentialsLoginDomain = $xmCloudClientCredentialsLoginDomain.Split("=")[1]
	$xmCloudClientCredentialsLoginAudience = $xmCloudClientCredentialsLoginAudience.Split("=")[1]
	$xmCloudClientCredentialsLoginClientId = $xmCloudClientCredentialsLoginClientId.Split("=")[1]
	$xmCloudClientCredentialsLoginClientSecret = $xmCloudClientCredentialsLoginClientSecret.Split("=")[1]
}

#set nuget version
$xmCloudBuild = Get-Content "xmcloud.build.json" | ConvertFrom-Json
Set-EnvFileVariable "NODEJS_VERSION" -Value $xmCloudBuild.renderingHosts.xmcloudpreview.nodeVersion -Path $envPath

# Double check whether init has been run
$envCheckVariable = "HOST_LICENSE_FOLDER"
$envCheck = $envContent | Where-Object { $_ -imatch "^$envCheckVariable=.+" }
if (-not $envCheck) {
    throw "$envCheckVariable does not have a value. Did you run 'init.ps1 -InitEnv'?"
}

Write-Host "Keeping XM Cloud base image up to date" -ForegroundColor Green
docker pull "$($sitecoreDockerRegistry)sitecore-xmcloud-cm:$($sitecoreVersion)"

if(-not $SkipBuild) {
    # Build all containers in the Sitecore instance, forcing a pull of latest base containers
    Write-Host "Building containers..." -ForegroundColor Green
    docker-compose --env-file $envPath build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container build failed, see errors above."
    }
}

# Start the Sitecore instance
Write-Host "Starting Sitecore environment..." -ForegroundColor Green
docker-compose --env-file $envPath up -d

# Wait for Traefik to expose CM route
Write-Host "Waiting for CM to become available..." -ForegroundColor Green
$startTime = Get-Date
do {
    Start-Sleep -Milliseconds 100
    try {
        $status = Invoke-RestMethod "http://localhost:8079/api/http/routers/cm-secure@docker"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -ne "404") {
            throw
        }
    }
} while ($status.status -ne "enabled" -and $startTime.AddSeconds(15) -gt (Get-Date))
if (-not $status.status -eq "enabled") {
    $status
    Write-Error "Timeout waiting for Sitecore CM to become available via Traefik proxy. Check CM container logs."
}

Write-Host "Restoring Sitecore CLI..." -ForegroundColor Green
    dotnet tool restore
Write-Host "Installing Sitecore CLI Plugins..."
dotnet sitecore --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unexpected error installing Sitecore CLI Plugins"
}

Write-Host "Logging into Sitecore..." -ForegroundColor Green
if ($ClientCredentialsLogin -eq "true") {
    dotnet sitecore cloud login --client-id $xmCloudClientCredentialsLoginClientId --client-secret $xmCloudClientCredentialsLoginClientSecret --client-credentials true
    dotnet sitecore login --authority $xmCloudClientCredentialsLoginDomain --audience $xmCloudClientCredentialsLoginAudience --client-id $xmCloudClientCredentialsLoginClientId --client-secret $xmCloudClientCredentialsLoginClientSecret --cm https://$xmCloudHost --client-credentials true --allow-write true
}
else {
    dotnet sitecore cloud login
    dotnet sitecore connect --ref xmcloud --cm https://$xmCloudHost --allow-write true -n default
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to log into Sitecore, did the Sitecore environment start correctly? See logs above."
}

if(-not $SkipIndexing) {
    # Populate Solr managed schemas to avoid errors during item deploy
    Write-Host "Populating Solr managed schema..." -ForegroundColor Green
    dotnet sitecore index schema-populate
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Populating Solr managed schema failed, see errors above."
    }

    # Rebuild indexes
    Write-Host "Rebuilding indexes ..." -ForegroundColor Green
    dotnet sitecore index rebuild
}

if(-not $SkipPush) {
    ##
    ## This script will sync the JSS sample site on first run, and then serialize it.
    ## Subsequent executions will only push the serialized site. You may wish to remove /
    ## simplify this logic if using this starter for your own development.
    ##

    # JSS sample has already been deployed and serialized, push the serialized items
    if (Test-Path .\src\items\content) {

        Write-Host "Pushing items to Sitecore..." -ForegroundColor Green
        dotnet sitecore ser push # --publish
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Serialization push failed, see errors above."
        }

    # JSS sample has not been deployed yet. Use its deployment process to initialize.
    } else {

        # Some items are needed for JSS to be able to deploy.
        Write-Host "Pushing init items to Sitecore..." -ForegroundColor Green
        dotnet sitecore ser push --include InitItems
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Serialization push failed, see errors above."
        }

        Write-Host "Deploying JSS application..." -ForegroundColor Green
        Push-Location src\rendering
        try {
            jss deploy items -c -d
        } finally {
            Pop-Location
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "JSS deploy failed, see errors above."
        }
        dotnet sitecore publish
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Item publish failed, see errors above."
        }

        Write-Host "Pulling JSS deployed items..." -ForegroundColor Green
        dotnet sitecore ser pull
    }

    Write-Host "Pushing sitecore API key" -ForegroundColor Green
    & docker\build\cm\templates\import-templates.ps1 -RenderingSiteName "xmcloudpreview" -SitecoreApiKey $sitecoreApiKey
}

if ((-not $SkipOpen) -and ($ClientCredentialsLogin -ne "true")) {
    Write-Host "Opening site..." -ForegroundColor Green
    
    Start-Process https://xmcloudcm.localhost/sitecore/
    Start-Process https://www.xmcloudpreview.localhost/
}

Write-Host ""
Write-Host "Use the following command to monitor your Rendering Host:" -ForegroundColor Green
Write-Host "docker-compose logs -f rendering"
Write-Host ""
