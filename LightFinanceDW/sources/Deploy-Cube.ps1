<#
=======================================================================
  Deploy-Cube.ps1  (v2 - based on a teammate's approach)
  Deploys and processes the SSAS multidimensional project LightFinanceDW_Cube
  with the Analysis Services libraries (AMO) shipped with SSMS 22.

  WHY: "Deploy" in Visual Studio fails on this PC: the libraries of the
  Visual Studio extension reject the "StandardDeveloper64" edition of SQL
  Server 2025, while the SSMS 22 libraries accept it (SSMS connects to SSAS).

  BEFORE: build the project in Visual Studio (right-click > "Générer").
          Rebuild after every change made to the cube or its dimensions.

  RUN (PowerShell):
     powershell -ExecutionPolicy Bypass -File .\Deploy-Cube.ps1
  or with explicit values:
     powershell -ExecutionPolicy Bypass -File .\Deploy-Cube.ps1 -AsDatabase "<...>\bin\LightFinanceDW_Cube.asdatabase" -Server localhost
=======================================================================
#>
param(
    [string]$AsDatabase   = '',                       # empty = searched automatically on the Desktop
    [string]$DatabaseName = 'LightFinanceDW_Cube',    # name of the SSAS database to create
    [string]$Server       = 'localhost'               # localhost\NAME for a named SSAS instance
)
$ErrorActionPreference = 'Stop'

# ---------- 1. Find the built project (.asdatabase) ----------
if (-not $AsDatabase) {
    $found = Get-ChildItem -Path "$env:USERPROFILE\Desktop" -Recurse -Filter "$DatabaseName.asdatabase" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $found) { throw "No $DatabaseName.asdatabase found on the Desktop. Build the project in Visual Studio first, or pass -AsDatabase." }
    $AsDatabase = $found.FullName
}
if (-not (Test-Path $AsDatabase)) { throw "File not found: $AsDatabase" }
$built = (Get-Item $AsDatabase).LastWriteTime
Write-Host "Project file : $AsDatabase" -ForegroundColor Cyan
Write-Host "Built on     : $built  (rebuild in Visual Studio if you changed the cube since)" -ForegroundColor Cyan

# ---------- 2. Load the Analysis Services libraries of SSMS 22 ----------
$ide = 'C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE'
if (-not (Test-Path "$ide\Microsoft.AnalysisServices.dll")) {
    # SSMS installed elsewhere: look for the library under Program Files
    $dll = Get-ChildItem 'C:\Program Files\Microsoft SQL Server Management Studio*' -Recurse `
               -Filter 'Microsoft.AnalysisServices.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $dll) { throw 'Microsoft.AnalysisServices.dll not found: is SSMS 22 installed with its Analysis Services component?' }
    $ide = $dll.DirectoryName
}
[void][Reflection.Assembly]::LoadFrom("$ide\Microsoft.AnalysisServices.Core.dll")
[void][Reflection.Assembly]::LoadFrom("$ide\Microsoft.AnalysisServices.dll")
Write-Host "AMO libraries: $ide" -ForegroundColor Cyan

# ---------- 3. Read the project definition ----------
$reader = [System.Xml.XmlReader]::Create($AsDatabase)
$db = New-Object Microsoft.AnalysisServices.Database
[void][Microsoft.AnalysisServices.Utils]::Deserialize($reader, $db)
$reader.Close()
$db.ID   = $DatabaseName
$db.Name = $DatabaseName

# ---------- 4. Deploy and process ----------
$srv = New-Object Microsoft.AnalysisServices.Server
try {
    $srv.Connect("Data Source=$Server")
    Write-Host "Connected to : $Server (edition: $($srv.Edition), version: $($srv.Version))" -ForegroundColor Cyan

    $existing = $srv.Databases.FindByName($DatabaseName)
    if ($existing) { $existing.Drop(); Write-Host "Previous version of $DatabaseName removed." -ForegroundColor Yellow }

    [void]$srv.Databases.Add($db)
    $db.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
    Write-Host "Deployed $DatabaseName. Processing (ProcessFull)..." -ForegroundColor Green

    $db.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)

    $srv.Refresh()
    $check = $srv.Databases.FindByName($DatabaseName)
    Write-Host "State : $($check.State)" -ForegroundColor Green
    Write-Host "Cubes : $(($check.Cubes | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor Green
    Write-Host "Dims  : $(($check.Dimensions | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor Green
}
catch {
    # Show the real Analysis Services message (often in the inner exceptions)
    Write-Host "`nERROR during deployment/processing:" -ForegroundColor Red
    $e = $_.Exception
    while ($e) { Write-Host " - $($e.Message)" -ForegroundColor Red; $e = $e.InnerException }
    exit 1
}
finally {
    if ($srv.Connected) { $srv.Disconnect() }
}