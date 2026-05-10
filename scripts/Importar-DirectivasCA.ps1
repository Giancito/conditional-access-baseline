param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Clear-Host

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " TechMentor - Conditional Access Framework" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Seleccione modo de implementacion:" -ForegroundColor Yellow
Write-Host ""
Write-Host "[1] Disabled / OFF"
Write-Host "[2] Report-only"
Write-Host "[3] Enabled / ON"
Write-Host ""

$ModeSelection = Read-Host "Opcion"

switch ($ModeSelection) {
    "1" { $PolicyState = "disabled" }
    "2" { $PolicyState = "enabledForReportingButNotEnforced" }
    "3" {
        Write-Host ""
        Write-Host "Advertencia: se crearan politicas habilitadas. Validar primero en Report-only." -ForegroundColor Red
        $ConfirmEnabled = Read-Host "Confirmar Enabled / ON? [S/N]"
        if ($ConfirmEnabled -notin @("S","s","Y","y")) {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            exit
        }
        $PolicyState = "enabled"
    }
    default {
        Write-Host "Opcion invalida. Se usara Disabled / OFF." -ForegroundColor Yellow
        $PolicyState = "disabled"
    }
}

Write-Host ""
Write-Host "Seleccione fase de implementacion:" -ForegroundColor Yellow
Write-Host ""
Write-Host "[1] Usuarios base"
Write-Host "[2] Invitados"
Write-Host "[3] Administradores"
Write-Host "[4] Cuentas de servicio"
Write-Host "[5] Identidades de carga de trabajo"
Write-Host "[6] Agentes IA"
Write-Host "[7] Todas las politicas"
Write-Host ""

$PhaseSelection = Read-Host "Opcion"

switch ($PhaseSelection) {
    "1" {
        # Usuarios base
        $PolicyFilter = @(
            "CA001","CA002","CA003","CA004","CA005",
            "CA006","CA007","CA008","CA009","CA010",
            "CA011","CA012","CA013","CA014","CA015",
            "CA016","CA017","CA018","CA026","CA027"
        )
        $PhaseName = "Usuarios base"
    }
    "2" {
        # Invitados y colaboracion externa
        $PolicyFilter = @("CA019","CA020")
        $PhaseName = "Invitados"
    }
    "3" {
        # Cuentas administrativas
        $PolicyFilter = @("CA021","CA022","CA023","CA024","CA025")
        $PhaseName = "Administradores"
    }
    "4" {
        # Cuentas de servicio tradicionales
        $PolicyFilter = @("CA028")
        $PhaseName = "Cuentas de servicio"
    }
    "5" {
        # Identidades de carga de trabajo / service principals
        $PolicyFilter = @("CA029","CA030","CA031")
        $PhaseName = "Identidades de carga de trabajo"
    }
    "6" {
        # Agentes IA
        $PolicyFilter = @("CA032")
        $PhaseName = "Agentes IA"
    }
    "7" {
        # Todas las politicas disponibles en la carpeta policies
        $PolicyFilter = @("CA")
        $PhaseName = "Todas las politicas"
    }
    default {
        Write-Host "Opcion invalida. Se usara Usuarios base." -ForegroundColor Yellow
        $PolicyFilter = @(
            "CA001","CA002","CA003","CA004","CA005",
            "CA006","CA007","CA008","CA009","CA010",
            "CA011","CA012","CA013","CA014","CA015",
            "CA016","CA017","CA018","CA026","CA027"
        )
        $PhaseName = "Usuarios base"
    }
}

Write-Host ""
Write-Host "Modo seleccionado : $PolicyState" -ForegroundColor Green
Write-Host "Fase seleccionada : $PhaseName" -ForegroundColor Green
Write-Host ""

$Confirm = Read-Host "Desea continuar? [S/N]"
if ($Confirm -notin @("S","s","Y","y")) {
    Write-Host "Operacion cancelada." -ForegroundColor Yellow
    exit
}

$BasePath = Split-Path -Parent $PSScriptRoot
$GroupsPath = Join-Path $BasePath "groups\groups.json"
$LocationsPath = Join-Path $BasePath "namedLocations\namedLocations.json"
$PoliciesPath = Join-Path $BasePath "policies"
$SettingsPath = Join-Path $BasePath "config\settings.json"

$ApiRoot = "https://graph.microsoft.com/beta"

$GraphExplorerAppId = "de8bc8b5-d9f9-48b1-a8ad-b748da725064"
$IntuneEnrollmentAppId = "d4ebce55-015a-49b5-a083-c84d1797ae8c"
$AzureDevOpsAppId = "499b84ac-1321-427f-aa17-267ca6975798"

function Get-JsonFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "No se encontro el archivo: $Path"
    }

    Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 100
}

function Write-GraphError {
    param($ErrorRecord)

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        Write-Host $ErrorRecord.ErrorDetails.Message -ForegroundColor DarkYellow
    }
    else {
        Write-Host $ErrorRecord.Exception.Message -ForegroundColor DarkYellow
    }
}

function Invoke-GraphJson {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter()]$Body
    )

    if ($WhatIf) {
        Write-Host "WhatIf: $Method $Uri" -ForegroundColor Yellow
        return $null
    }

    try {
        if ($null -ne $Body) {
            $JsonBody = $Body | ConvertTo-Json -Depth 100
            return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Body $JsonBody -ContentType "application/json"
        }

        return Invoke-MgGraphRequest -Method $Method -Uri $Uri
    }
    catch {
        Write-GraphError -ErrorRecord $_
        throw
    }
}

function Get-GraphPaged {
    param([Parameter(Mandatory)][string]$Uri)

    $Results = @()
    $Next = $Uri

    while ($Next) {
        $Response = Invoke-MgGraphRequest -Method GET -Uri $Next
        if ($Response.value) {
            $Results += $Response.value
        }
        $Next = $Response.'@odata.nextLink'
    }

    return $Results
}

function Get-GroupByDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)

    $SafeName = $DisplayName.Replace("'","''")
    $Uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$SafeName'&`$select=id,displayName"
    $Result = Invoke-MgGraphRequest -Method GET -Uri $Uri
    return $Result.value | Select-Object -First 1
}

function New-OrGetGroup {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter()][string]$Description
    )

    $Existing = Get-GroupByDisplayName -DisplayName $DisplayName

    if ($Existing -and $Existing.id) {
        Write-Host "Grupo existente: $DisplayName ($($Existing.id))" -ForegroundColor Green
        return $Existing
    }

    if ($WhatIf) {
        Write-Host "WhatIf: crear grupo $DisplayName" -ForegroundColor Yellow
        return [pscustomobject]@{
            id = "__WHATIF_$($DisplayName)_ID__"
            displayName = $DisplayName
        }
    }

    $MailNickname = ($DisplayName -replace "[^a-zA-Z0-9]","").ToLower()
    if ([string]::IsNullOrWhiteSpace($MailNickname)) {
        $MailNickname = "grpca" + (Get-Random)
    }

    Write-Host "Creando grupo: $DisplayName" -ForegroundColor Yellow

    $Body = @{
        displayName = $DisplayName
        description = $Description
        mailEnabled = $false
        mailNickname = $MailNickname
        securityEnabled = $true
        groupTypes = @()
    }

    $Created = Invoke-GraphJson -Method POST -Uri "https://graph.microsoft.com/v1.0/groups" -Body $Body
    Start-Sleep -Seconds 2

    if (-not $Created.id) {
        $Created = Get-GroupByDisplayName -DisplayName $DisplayName
    }

    return $Created
}

function Assert-NotEmpty {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "No se pudo resolver el valor requerido: $Name. Revise permisos, grupos o named locations."
    }
}

function Get-ServicePrincipalByAppId {
    param([Parameter(Mandatory)][string]$AppId)

    if ([string]::IsNullOrWhiteSpace($AppId)) { return $null }

    if ($AppId -in @("All", "Office365")) {
        return [pscustomobject]@{ appId = $AppId; displayName = $AppId }
    }

    try {
        return Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$AppId')" -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Test-CloudAppExists {
    param([Parameter(Mandatory)][string]$AppId)

    if ($AppId -in @("All", "Office365")) { return $true }
    if ($AppId -like "urn:*") { return $true }

    return ($null -ne (Get-ServicePrincipalByAppId -AppId $AppId))
}

function New-OrGetServicePrincipalByAppId {
    param(
        [Parameter(Mandatory)][string]$AppId,
        [Parameter()][string]$DisplayName = $AppId
    )

    $Current = Get-ServicePrincipalByAppId -AppId $AppId

    if ($Current) {
        Write-Host "Enterprise App existente: $DisplayName" -ForegroundColor Green
        return $Current
    }

    if ($WhatIf) {
        Write-Host "WhatIf: crear Enterprise App / Service Principal: $DisplayName ($AppId)" -ForegroundColor Yellow
        return [pscustomobject]@{ appId = $AppId; displayName = $DisplayName }
    }

    Write-Host "Creando Enterprise App / Service Principal: $DisplayName ($AppId)" -ForegroundColor Yellow

    $Body = @{ appId = $AppId }

    try {
        return Invoke-GraphJson -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Body $Body
    }
    catch {
        Write-Host "No se pudo crear Enterprise App / Service Principal: $DisplayName" -ForegroundColor Red
        Write-GraphError -ErrorRecord $_
        return $null
    }
}

function Ensure-DeviceRegistrationMfaNotRequired {
    Write-Host ""
    Write-Host "Validando MFA tenant-wide para registro o union de dispositivos..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "WhatIf: cambiar multiFactorAuthConfiguration a notRequired si estuviera en required." -ForegroundColor Yellow
        return
    }

    try {
        $Uri = "https://graph.microsoft.com/v1.0/policies/deviceRegistrationPolicy"
        $Policy = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop

        if ($Policy.multiFactorAuthConfiguration -eq "notRequired") {
            Write-Host "Configuracion correcta: multiFactorAuthConfiguration = notRequired" -ForegroundColor Green
            return
        }

        Write-Host "Configuracion actual: multiFactorAuthConfiguration = $($Policy.multiFactorAuthConfiguration)" -ForegroundColor Yellow
        Write-Host "Se cambiara a notRequired para usar Conditional Access en Register or Join Devices." -ForegroundColor Yellow

        $Body = @{
            userDeviceQuota = $Policy.userDeviceQuota
            multiFactorAuthConfiguration = "notRequired"
            azureADRegistration = $Policy.azureADRegistration
            azureADJoin = $Policy.azureADJoin
            localAdminPassword = $Policy.localAdminPassword
        }

        Invoke-GraphJson -Method PUT -Uri $Uri -Body $Body | Out-Null
        Write-Host "Configuracion actualizada: multiFactorAuthConfiguration = notRequired" -ForegroundColor Green
    }
    catch {
        Write-Host "No se pudo validar o actualizar Device Registration Policy." -ForegroundColor Yellow
        Write-Host "Requiere permisos Policy.ReadWrite.DeviceConfiguration y rol adecuado." -ForegroundColor Yellow
        Write-GraphError -ErrorRecord $_
    }
}

function Test-WorkloadIdPremiumAvailable {
    Write-Host ""
    Write-Host "Validando licenciamiento Microsoft Entra Workload ID Premium..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "WhatIf: validar licenciamiento Workload ID Premium." -ForegroundColor Yellow
        return $true
    }

    try {
        $Skus = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/subscribedSkus" -ErrorAction Stop
        $Detected = @()

        foreach ($Sku in @($Skus.value)) {
            $SkuText = "$($Sku.skuPartNumber) $($Sku.skuId)"

            if ($SkuText -match "WORKLOAD" -or $SkuText -match "WID") {
                $Detected += $Sku
            }

            foreach ($Plan in @($Sku.servicePlans)) {
                $PlanText = "$($Plan.servicePlanName) $($Plan.servicePlanId)"
                if ($PlanText -match "WORKLOAD" -or $PlanText -match "WID") {
                    $Detected += $Sku
                }
            }
        }

        $Detected = $Detected | Select-Object -Unique

        if ($Detected.Count -gt 0) {
            Write-Host "Licencia Workload ID Premium detectada." -ForegroundColor Green
            return $true
        }

        Write-Host "No se detecto licencia Workload ID Premium. Se omitiran CA029, CA030 y CA031. CA032 de Agentes IA se intentara crear si el tenant soporta la plantilla." -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Host "No se pudo validar licenciamiento Workload ID Premium. Se omitiran CA029, CA030 y CA031. CA032 de Agentes IA se intentara crear si el tenant soporta la plantilla." -ForegroundColor Yellow
        Write-GraphError -ErrorRecord $_
        return $false
    }
}

function Resolve-PrivilegedServicePrincipalId {
    param($Settings)

    if (-not $script:WorkloadIdPremiumAvailable) {
        return "__REEMPLAZAR_SERVICE_PRINCIPAL_ID__"
    }

    if ($Settings.privilegedServicePrincipalId -and -not [string]::IsNullOrWhiteSpace($Settings.privilegedServicePrincipalId)) {
        return [string]$Settings.privilegedServicePrincipalId
    }

    Write-Host ""
    Write-Host "CA031/CA032 requieren el ObjectId del Service Principal a proteger." -ForegroundColor Yellow
    Write-Host "No es el AppId/ClientId. Debe ser el ObjectId de Enterprise Applications." -ForegroundColor Yellow
    Write-Host "Si no deseas crear esas politicas ahora, presiona Enter." -ForegroundColor Yellow
    $SpId = Read-Host "Ingrese ObjectId del Service Principal"

    if ([string]::IsNullOrWhiteSpace($SpId)) {
        return "__REEMPLAZAR_SERVICE_PRINCIPAL_ID__"
    }

    return $SpId.Trim()
}

function Test-IsPlaceholderOrEmpty {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    if ($Value -like "__*__") { return $true }
    if ($Value -like "__REEMPLAZAR*") { return $true }
    return $false
}

function Test-PolicyHasInvalidObjectReferences {
    param([Parameter(Mandatory)]$PolicyObject)

    # Validar grupos solo si la propiedad existe realmente.
    # En PowerShell, @($null) genera un elemento vacio; por eso antes se estaban omitiendo politicas validas.
    if ($PolicyObject.conditions -and $PolicyObject.conditions.users) {
        $Users = $PolicyObject.conditions.users
        $UserProps = @($Users.PSObject.Properties.Name)

        if ($UserProps -contains "includeGroups" -and $null -ne $Users.includeGroups) {
            foreach ($GroupId in @($Users.includeGroups)) {
                if (Test-IsPlaceholderOrEmpty -Value $GroupId) {
                    return "Grupo incluido invalido o no resuelto: $GroupId"
                }
            }
        }

        if ($UserProps -contains "excludeGroups" -and $null -ne $Users.excludeGroups) {
            foreach ($GroupId in @($Users.excludeGroups)) {
                if (Test-IsPlaceholderOrEmpty -Value $GroupId) {
                    return "Grupo excluido invalido o no resuelto: $GroupId"
                }
            }
        }

        if ($UserProps -contains "includeRoles" -and $null -ne $Users.includeRoles) {
            foreach ($RoleId in @($Users.includeRoles)) {
                if (Test-IsPlaceholderOrEmpty -Value $RoleId) {
                    return "Rol incluido invalido o no resuelto: $RoleId"
                }
            }
        }

        if ($UserProps -contains "excludeRoles" -and $null -ne $Users.excludeRoles) {
            foreach ($RoleId in @($Users.excludeRoles)) {
                if (Test-IsPlaceholderOrEmpty -Value $RoleId) {
                    return "Rol excluido invalido o no resuelto: $RoleId"
                }
            }
        }
    }

    if ($PolicyObject.conditions -and $PolicyObject.conditions.locations) {
        $Locations = $PolicyObject.conditions.locations
        $LocationProps = @($Locations.PSObject.Properties.Name)

        if ($LocationProps -contains "includeLocations" -and $null -ne $Locations.includeLocations) {
            foreach ($LocationId in @($Locations.includeLocations)) {
                if ($LocationId -ne "All" -and (Test-IsPlaceholderOrEmpty -Value $LocationId)) {
                    return "Ubicacion incluida invalida o no resuelta: $LocationId"
                }
            }
        }

        if ($LocationProps -contains "excludeLocations" -and $null -ne $Locations.excludeLocations) {
            foreach ($LocationId in @($Locations.excludeLocations)) {
                if ($LocationId -ne "All" -and (Test-IsPlaceholderOrEmpty -Value $LocationId)) {
                    return "Ubicacion excluida invalida o no resuelta: $LocationId"
                }
            }
        }
    }

    if ($PolicyObject.conditions -and $PolicyObject.conditions.clientApplications) {
        $ClientApps = $PolicyObject.conditions.clientApplications
        $ClientAppProps = @($ClientApps.PSObject.Properties.Name)

        if ($ClientAppProps -contains "includeServicePrincipals" -and $null -ne $ClientApps.includeServicePrincipals) {
            foreach ($SpId in @($ClientApps.includeServicePrincipals)) {
                if (Test-IsPlaceholderOrEmpty -Value $SpId) {
                    return "Service Principal invalido o no configurado: $SpId"
                }
            }
        }

        if ($ClientAppProps -contains "excludeServicePrincipals" -and $null -ne $ClientApps.excludeServicePrincipals) {
            foreach ($SpId in @($ClientApps.excludeServicePrincipals)) {
                if (Test-IsPlaceholderOrEmpty -Value $SpId) {
                    return "Service Principal excluido invalido o no configurado: $SpId"
                }
            }
        }
    }

    return $null
}

function Normalize-ConditionalAccessPolicy {
    param([Parameter(Mandatory)]$PolicyObject)

    if ($PolicyObject.PSObject.Properties.Name -contains "description") {
        $PolicyObject.PSObject.Properties.Remove("description")
    }

    if ($PolicyObject.conditions -and $PolicyObject.conditions.applications) {
        $Apps = $PolicyObject.conditions.applications

        if ($Apps.excludeApplications) {
            $CleanExcludeApps = @()

            foreach ($AppId in @($Apps.excludeApplications)) {
                if (Test-CloudAppExists -AppId $AppId) {
                    $CleanExcludeApps += $AppId
                }
                else {
                    Write-Host "Advertencia: App no encontrada y sera omitida de excludeApplications: $AppId" -ForegroundColor Yellow
                }
            }

            if ($CleanExcludeApps.Count -gt 0) {
                $Apps.excludeApplications = $CleanExcludeApps
            }
            else {
                $Apps.PSObject.Properties.Remove("excludeApplications") | Out-Null
            }
        }

        if ($Apps.includeApplications) {
            $CleanIncludeApps = @()
            $InvalidIncludeApps = @()

            foreach ($AppId in @($Apps.includeApplications)) {
                if (Test-CloudAppExists -AppId $AppId) {
                    $CleanIncludeApps += $AppId
                }
                else {
                    $InvalidIncludeApps += $AppId
                }
            }

            if ($InvalidIncludeApps.Count -gt 0) {
                Write-Host "Advertencia: App no encontrada en el tenant: $($InvalidIncludeApps -join ', ')" -ForegroundColor Yellow

                if ($CleanIncludeApps.Count -eq 0) {
                    $PolicyObject | Add-Member -NotePropertyName "_SkipPolicy" -NotePropertyValue $true -Force
                    $PolicyObject | Add-Member -NotePropertyName "_SkipReason" -NotePropertyValue "Aplicacion no encontrada: $($InvalidIncludeApps -join ', ')" -Force
                    return $PolicyObject
                }

                $Apps.includeApplications = $CleanIncludeApps
            }
        }
    }

    return $PolicyObject
}

function Get-NamedLocation {
    param([Parameter(Mandatory)][string]$DisplayName)

    $Response = Invoke-MgGraphRequest -Method GET -Uri "$ApiRoot/identity/conditionalAccess/namedLocations"
    $Response.value | Where-Object { $_.displayName -eq $DisplayName } | Select-Object -First 1
}

function New-OrGetCountryNamedLocation {
    param([Parameter(Mandatory)]$Item)

    $Current = Get-NamedLocation -DisplayName $Item.displayName

    if ($Current -and $Current.id) {
        Write-Host "Ubicacion existente: $($Item.displayName) ($($Current.id))" -ForegroundColor Green
        return $Current
    }

    $Body = @{
        "@odata.type" = "#microsoft.graph.countryNamedLocation"
        displayName = $Item.displayName
        countriesAndRegions = @($Item.countriesAndRegions)
        includeUnknownCountriesAndRegions = [bool]$Item.includeUnknownCountriesAndRegions
    }

    Write-Host "Creando ubicacion de paises: $($Item.displayName)" -ForegroundColor Yellow
    Invoke-GraphJson -Method POST -Uri "$ApiRoot/identity/conditionalAccess/namedLocations" -Body $Body | Out-Null
    Start-Sleep -Seconds 2
    Get-NamedLocation -DisplayName $Item.displayName
}

function New-OrGetIpNamedLocation {
    param([Parameter(Mandatory)]$Item)

    $Current = Get-NamedLocation -DisplayName $Item.displayName

    if ($Current -and $Current.id) {
        Write-Host "Ubicacion existente: $($Item.displayName) ($($Current.id))" -ForegroundColor Green
        return $Current
    }

    $IpRanges = @(
        foreach ($Ip in @($Item.ipRanges)) {
            @{
                "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                cidrAddress = [string]$Ip
            }
        }
    )

    $Body = @{
        "@odata.type" = "#microsoft.graph.ipNamedLocation"
        displayName = $Item.displayName
        isTrusted = $true
        ipRanges = $IpRanges
    }

    Write-Host "Creando ubicacion IP: $($Item.displayName)" -ForegroundColor Yellow
    Invoke-GraphJson -Method POST -Uri "$ApiRoot/identity/conditionalAccess/namedLocations" -Body $Body | Out-Null
    Start-Sleep -Seconds 2
    Get-NamedLocation -DisplayName $Item.displayName
}

function Get-ConditionalAccessPolicy {
    param([Parameter(Mandatory)][string]$DisplayName)

    $Response = Invoke-MgGraphRequest -Method GET -Uri "$ApiRoot/identity/conditionalAccess/policies"
    $Response.value | Where-Object { $_.displayName -eq $DisplayName } | Select-Object -First 1
}

function Import-ConditionalAccessPolicy {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$ReplacementMap,
        [Parameter(Mandatory)][string]$State
    )

    $Raw = Get-Content -Path $Path -Raw

    foreach ($Key in $ReplacementMap.Keys) {
        $Raw = $Raw.Replace($Key, [string]$ReplacementMap[$Key])
    }

    $Raw = $Raw.Replace("__GRP_CA_SERVICE_ACCOUNTS_ID__", [string]$ReplacementMap["__GRP_CA_CUENTAS_SERVICIO_ID__"])
    $Raw = $Raw.Replace("__LOC_IPS_CONFIANZA_WORKLOAD_IDENTITY_ID__", [string]$ReplacementMap["__LOC_IPS_CONFIANZA_IDENTIDADES_CARGA_TRABAJO_ID__"])

    $Body = $Raw | ConvertFrom-Json -Depth 100
    $Body.state = $State
    $Body = Normalize-ConditionalAccessPolicy -PolicyObject $Body

    if ($Body.displayName -like "CA029 - *" -or $Body.displayName -like "CA030 - *" -or $Body.displayName -like "CA031 - *") {
        if (-not $script:WorkloadIdPremiumAvailable) {
            Write-Host "Omitida: $($Body.displayName) - No se detecto licencia Workload ID Premium." -ForegroundColor Yellow
            return
        }
    }

    $InvalidReference = Test-PolicyHasInvalidObjectReferences -PolicyObject $Body
    if ($InvalidReference) {
        Write-Host "Omitida: $($Body.displayName) - $InvalidReference" -ForegroundColor Yellow
        return
    }

    if ($Body.PSObject.Properties.Name -contains "_SkipPolicy" -and $Body._SkipPolicy -eq $true) {
        Write-Host "Omitida: $($Body.displayName) - $($Body._SkipReason)" -ForegroundColor Yellow
        return
    }

    foreach ($Prop in @("_SkipPolicy", "_SkipReason")) {
        if ($Body.PSObject.Properties.Name -contains $Prop) {
            $Body.PSObject.Properties.Remove($Prop)
        }
    }

    $Existing = Get-ConditionalAccessPolicy -DisplayName $Body.displayName

    if ($Existing) {
        Write-Host "Politica existente: $($Body.displayName)" -ForegroundColor Green
        return
    }

    Write-Host "Importando: $($Body.displayName)" -ForegroundColor Yellow
    Invoke-GraphJson -Method POST -Uri "$ApiRoot/identity/conditionalAccess/policies" -Body $Body | Out-Null
}

Write-Host ""
Write-Host "Conectando a Microsoft Graph..." -ForegroundColor Cyan

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

Connect-MgGraph -Scopes @(
    "Policy.ReadWrite.ConditionalAccess",
    "Policy.Read.All",
    "Group.ReadWrite.All",
    "Directory.Read.All",
    "Application.Read.All",
    "Application.ReadWrite.All",
    "Policy.ReadWrite.DeviceConfiguration",
    "Organization.Read.All"
) -NoWelcome

Write-Host ""
Write-Host "Validando Enterprise Apps requeridas..." -ForegroundColor Cyan

New-OrGetServicePrincipalByAppId -AppId $GraphExplorerAppId -DisplayName "Microsoft Graph Explorer" | Out-Null
New-OrGetServicePrincipalByAppId -AppId $IntuneEnrollmentAppId -DisplayName "Microsoft Intune Enrollment" | Out-Null
New-OrGetServicePrincipalByAppId -AppId $AzureDevOpsAppId -DisplayName "Azure DevOps" | Out-Null

Ensure-DeviceRegistrationMfaNotRequired

Write-Host ""
Write-Host "Creando grupos requeridos..." -ForegroundColor Cyan

$GroupsConfig = Get-JsonFile -Path $GroupsPath
$GroupMap = @{}

foreach ($Item in $GroupsConfig.groups) {
    $Group = New-OrGetGroup -DisplayName $Item.displayName -Description $Item.description

    if ($Group -and $Group.id) {
        $GroupMap[$Item.displayName] = [string]$Group.id
    }
    else {
        throw "No se pudo resolver el grupo $($Item.displayName)."
    }
}

foreach ($RequiredGroup in @("GRP-CA-EXC-EMERGENCIA","GRP-CA-EXC-SERVICIOS","GRP-CA-CUENTAS-SERVICIO")) {
    if (-not $GroupMap.ContainsKey($RequiredGroup) -or [string]::IsNullOrWhiteSpace($GroupMap[$RequiredGroup])) {
        $Resolved = Get-GroupByDisplayName -DisplayName $RequiredGroup
        if ($Resolved -and $Resolved.id) {
            $GroupMap[$RequiredGroup] = [string]$Resolved.id
        }
    }

    Assert-NotEmpty -Name $RequiredGroup -Value $GroupMap[$RequiredGroup]
}

Write-Host ""
Write-Host "IDs de grupos resueltos:" -ForegroundColor Cyan
$GroupMap.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)" -ForegroundColor DarkGreen
}

Write-Host ""
Write-Host "Creando ubicaciones con nombre..." -ForegroundColor Cyan

$LocationsConfig = Get-JsonFile -Path $LocationsPath
$LocationMap = @{}

foreach ($Item in $LocationsConfig.countryNamedLocations) {
    $Location = New-OrGetCountryNamedLocation -Item $Item

    if ($Location -and $Location.id) {
        $LocationMap[$Item.displayName] = [string]$Location.id
    }
    else {
        throw "No se pudo resolver la ubicacion $($Item.displayName)."
    }
}

foreach ($Item in $LocationsConfig.ipNamedLocations) {
    $Location = New-OrGetIpNamedLocation -Item $Item

    if ($Location -and $Location.id) {
        $LocationMap[$Item.displayName] = [string]$Location.id
    }
    else {
        throw "No se pudo resolver la ubicacion $($Item.displayName)."
    }
}

foreach ($RequiredLocation in @("PAISES PERMITIDOS","PAISES PERMITIDOS - CUENTAS DE SERVICIO","UBICACIONES CONFIANZA - CUENTAS DE SERVICIO","UBICACIONES CONFIANZA - IDENTIDADES DE CARGA DE TRABAJO")) {
    Assert-NotEmpty -Name $RequiredLocation -Value $LocationMap[$RequiredLocation]
}

$Settings = Get-JsonFile -Path $SettingsPath
$script:WorkloadIdPremiumAvailable = Test-WorkloadIdPremiumAvailable

$ReplacementMap = @{
    "__GRP_CA_EXC_EMERGENCIA_ID__" = [string]$GroupMap["GRP-CA-EXC-EMERGENCIA"]
    "__GRP_CA_EXC_SERVICIOS_ID__" = [string]$GroupMap["GRP-CA-EXC-SERVICIOS"]
    "__GRP_CA_CUENTAS_SERVICIO_ID__" = [string]$GroupMap["GRP-CA-CUENTAS-SERVICIO"]
    "__LOC_PAISES_PERMITIDOS_ID__" = [string]$LocationMap["PAISES PERMITIDOS"]
    "__LOC_PAISES_PERMITIDOS_SERVICIOS_ID__" = [string]$LocationMap["PAISES PERMITIDOS - CUENTAS DE SERVICIO"]
    "__LOC_IPS_CONFIANZA_CUENTAS_SERVICIO_ID__" = [string]$LocationMap["UBICACIONES CONFIANZA - CUENTAS DE SERVICIO"]
    "__LOC_IPS_CONFIANZA_IDENTIDADES_CARGA_TRABAJO_ID__" = [string]$LocationMap["UBICACIONES CONFIANZA - IDENTIDADES DE CARGA DE TRABAJO"]
    "__AUTH_STRENGTH_PHISHING_RESISTANT_ID__" = [string]$Settings.phishingResistantAuthenticationStrengthId
    "__SERVICE_PRINCIPAL_PRIVILEGIADO_ID__" = [string](Resolve-PrivilegedServicePrincipalId -Settings $Settings)
}

foreach ($Key in @("__GRP_CA_EXC_EMERGENCIA_ID__","__GRP_CA_EXC_SERVICIOS_ID__","__GRP_CA_CUENTAS_SERVICIO_ID__","__LOC_PAISES_PERMITIDOS_ID__")) {
    Assert-NotEmpty -Name $Key -Value $ReplacementMap[$Key]
}

Write-Host ""
Write-Host "Filtrando politicas de la fase: $PhaseName" -ForegroundColor Cyan

# Crear indice de archivos existentes por ID CA###
$PolicyFiles = @{}
Get-ChildItem -Path $PoliciesPath -Filter "CA*.json" | Sort-Object Name | ForEach-Object {
    $PolicyId = $_.BaseName
    $PolicyFiles[$PolicyId] = $_
}

# Construir lista en orden exacto, sin usar .Add() para evitar errores de sobrecarga.
$Policies = @()

foreach ($PolicyId in $PolicyFilter) {

    if ($PolicyId -eq "CA") {
        $Policies = Get-ChildItem -Path $PoliciesPath -Filter "CA*.json" | Sort-Object Name
        break
    }

    if ($PolicyFiles.ContainsKey($PolicyId)) {
        $Policies += $PolicyFiles[$PolicyId]
    }
    else {
        Write-Host "Advertencia: no se encontro $PolicyId.json" -ForegroundColor Yellow
    }
}

if (-not $Policies -or $Policies.Count -eq 0) {
    Write-Host "No se encontraron politicas para la fase seleccionada." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Politicas a importar:" -ForegroundColor Cyan
$Policies | ForEach-Object { Write-Host "- $($_.Name)" }

Write-Host ""
$ContinueImport = Read-Host "Confirmar importacion de estas politicas? [S/N]"

if ($ContinueImport -notin @("S","s","Y","y")) {
    Write-Host "Importacion cancelada." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Importando politicas..." -ForegroundColor Cyan

foreach ($PolicyFile in $Policies) {
    try {
        Import-ConditionalAccessPolicy -Path $PolicyFile.FullName -ReplacementMap $ReplacementMap -State $PolicyState
    }
    catch {
        Write-Host "Error en $($PolicyFile.Name)" -ForegroundColor Red
        Write-GraphError -ErrorRecord $_
    }
}

Write-Host ""
Write-Host "Proceso finalizado." -ForegroundColor Green
Write-Host "Revisar las politicas en Microsoft Entra antes de habilitarlas en produccion." -ForegroundColor Yellow
