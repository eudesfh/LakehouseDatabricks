<#
.SYNOPSIS
  Apply (create or update) the Copiloto de Operações Genie space.

.PARAMETER Catalog
  Databricks catalog name (e.g. grid_dev or grid_intelligence).

.PARAMETER Profile
  Databricks CLI profile to use (default: grid_intelligence).

.PARAMETER SpaceId
  Existing space ID to update. Omit to create a new space.

.EXAMPLE
  # Create in dev
  .\apply.ps1 -Catalog grid_dev

  # Update existing space
  .\apply.ps1 -Catalog grid_dev -SpaceId <SPACE_ID>
#>
param(
  [Parameter(Mandatory)]
  [string]$Catalog,

  [string]$Profile = "grid_intelligence",

  [string]$SpaceId = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TemplateFile = Join-Path $PSScriptRoot "copiloto_operacoes.json"
$WarehouseId  = "b4361a7b081abb4c"
$Title        = "Copiloto de Operações — Luz do Vale"
$Description  = "Responde em português perguntas de diretoria sobre interrupções, chamados, qualidade de continuidade (DEC/FEC) e prioridade de inspeção, cruzando as quatro tabelas da camada gold da Luz do Vale Distribuidora S.A."
$ParentPath   = "/Workspace/Users/jnr.oliiver@gmail.com/genie_spaces"

# Substitute ${catalogo} placeholder
$RawJson = Get-Content $TemplateFile -Raw -Encoding UTF8
$Resolved = $RawJson -replace '\$\{catalogo\}', $Catalog

# Stringify the serialized_space for the API payload
$Stringified = $Resolved | & jq -c '.' | & jq -Rs '.'

# Ensure parent workspace path exists
Write-Host "Ensuring workspace path: $ParentPath"
databricks workspace mkdirs $ParentPath --profile $Profile

if ($SpaceId -eq "") {
  Write-Host "Creating new Genie space in catalog '$Catalog'..."
  $Result = databricks genie create-space --profile $Profile --json "{
    `"warehouse_id`": `"$WarehouseId`",
    `"title`": `"$Title`",
    `"description`": `"$Description`",
    `"parent_path`": `"$ParentPath`",
    `"serialized_space`": $Stringified
  }" -o json
  $SpaceId = ($Result | & jq -r '.space_id')
  Write-Host "Created space_id: $SpaceId"
} else {
  Write-Host "Updating Genie space $SpaceId in catalog '$Catalog'..."
  databricks genie update-space $SpaceId --profile $Profile --json "{
    `"warehouse_id`": `"$WarehouseId`",
    `"title`": `"$Title`",
    `"description`": `"$Description`",
    `"serialized_space`": $Stringified
  }" | Out-Null
  Write-Host "Updated space_id: $SpaceId"
}

Write-Host ""
Write-Host "Space URL: https://$(databricks auth env --profile $Profile -o json | jq -r '.env.DATABRICKS_HOST')/genie/rooms/$SpaceId"
Write-Host "space_id=$SpaceId"
