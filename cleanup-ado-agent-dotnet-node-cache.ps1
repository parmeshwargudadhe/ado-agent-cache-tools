Write-Output "Starting Azure DevOps agent cache CLEANUP..."
Write-Output "==================================================="

# 🔹 Hardcoded cutoff year
$TaskCutoffYear = 2024
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile = Join-Path $ScriptDirectory "ADO_Agent_Cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

$AgentHomes = @(
    "C:\agent",
    "E:\agent5",
    "E:\agent6",
    "E:\agent7",
    "E:\agent8",
    "E:\agent9",
    "E:\agent2",
    "E:\agents\agent1",
    "E:\agents\agent2",
    "E:\agents\agent3",
    "E:\agents\agent4",
    "E:\agents\agent5",
    "E:\agents\agent6"
)

function Get-MajorVersion($versionName) {
    if ($versionName -match '^\d+(\.\d+)*') {
        return [int]($versionName -split '\.')[0]
    }
    return $null
}

$ItemsToDelete = @()

# ==========================================================
# 🔎 DISCOVERY PHASE
# ==========================================================

foreach ($AgentHome in $AgentHomes) {

    $WorkDir = Join-Path $AgentHome "_work"
    if (-not (Test-Path $WorkDir)) { continue }

    # 1️⃣ Old Tasks
    $TasksDir = Join-Path $WorkDir "_tasks"
    if (Test-Path $TasksDir) {

        Get-ChildItem $TasksDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {

            $TaskFolder = $_.FullName

            Get-ChildItem $TaskFolder -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime.Year -lt $TaskCutoffYear } |
            ForEach-Object { $ItemsToDelete += $_ }

            Get-ChildItem $TaskFolder -File -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Extension -match '\.completed|\.node') -and
                $_.CreationTime.Year -lt $TaskCutoffYear
            } |
            ForEach-Object { $ItemsToDelete += $_ }
        }
    }

    # 2️⃣ .NET SDK < 8
    $DotnetSdkDir = Join-Path $WorkDir "_tool\dotnet\sdk"
    if (Test-Path $DotnetSdkDir) {

        Get-ChildItem $DotnetSdkDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $major = Get-MajorVersion $_.Name
            $major -and $major -lt 8
        } | ForEach-Object { $ItemsToDelete += $_ }

        Get-ChildItem $DotnetSdkDir -File -Filter "*.complete" -ErrorAction SilentlyContinue |
        Where-Object {
            $major = Get-MajorVersion $_.BaseName
            $major -and $major -lt 8
        } | ForEach-Object { $ItemsToDelete += $_ }
    }

    # 3️⃣ Shared Runtimes < 8
    $SharedBase = Join-Path $WorkDir "_tool\dotnet\shared"
    if (Test-Path $SharedBase) {

        $RuntimeFolders = @(
            "Microsoft.NETCore.App",
            "Microsoft.AspNetCore.App",
            "Microsoft.WindowsDesktop.App"
        )

        foreach ($runtime in $RuntimeFolders) {

            $RuntimePath = Join-Path $SharedBase $runtime

            if (Test-Path $RuntimePath) {
                Get-ChildItem $RuntimePath -Directory -ErrorAction SilentlyContinue |
                Where-Object {
                    $major = Get-MajorVersion $_.Name
                    $major -and $major -lt 8
                } | ForEach-Object { $ItemsToDelete += $_ }
            }
        }
    }

    # 4️⃣ Node < 18
    $NodeDir = Join-Path $WorkDir "_tool\node"
    if (Test-Path $NodeDir) {

        Get-ChildItem $NodeDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $major = Get-MajorVersion $_.Name
            $major -and $major -lt 18
        } | ForEach-Object { $ItemsToDelete += $_ }
    }
}

# Remove duplicates (important safety step)
$ItemsToDelete = $ItemsToDelete | Sort-Object FullName -Unique

# ==========================================================
# 📋 SHOW WHAT WILL BE DELETED
# ==========================================================

if ($ItemsToDelete.Count -eq 0) {
    Write-Output "Nothing found to delete."
    return
}

Write-Output ""
Write-Output "==================================================="
Write-Output "The following $($ItemsToDelete.Count) items will be deleted:"
Write-Output "==================================================="

$ItemsToDelete | Select-Object FullName, CreationTime | Format-Table -AutoSize

# ==========================================================
# 🔐 CONFIRMATION
# ==========================================================

$confirmation = Read-Host "`nType YES to proceed with deletion"

if ($confirmation -ne "YES") {
    Write-Output "Cleanup cancelled."
    return
}

# ==========================================================
# 🗑 ADVANCED DELETION PHASE
# ==========================================================

Write-Output "`nStarting deletion..."

$Deleted = @()
$Failed = @()

$total = $ItemsToDelete.Count
$current = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($item in $ItemsToDelete) {

    $current++
    $percent = [int](($current / $total) * 100)

    Write-Progress `
        -Activity "Azure DevOps Agent Cleanup" `
        -Status "Processing $current of $total" `
        -PercentComplete $percent `
        -CurrentOperation $item.FullName

    try {
        Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop
        $Deleted += $item.FullName
    }
    catch {
        $Failed += $item.FullName
    }
}

$stopwatch.Stop()
Write-Progress -Activity "Azure DevOps Agent Cleanup" -Completed

# ==========================================================
# 📝 LOGGING
# ==========================================================

"Azure DevOps Agent Cleanup Log - $(Get-Date)" | Out-File $LogFile
"===================================================" | Out-File $LogFile -Append
"" | Out-File $LogFile -Append

"Total Items Found: $total" | Out-File $LogFile -Append
"Deleted: $($Deleted.Count)" | Out-File $LogFile -Append
"Failed: $($Failed.Count)" | Out-File $LogFile -Append
"Duration: $($stopwatch.Elapsed.ToString())" | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"Deleted Items:" | Out-File $LogFile -Append
$Deleted | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"Failed Items:" | Out-File $LogFile -Append
$Failed | Out-File $LogFile -Append

# ==========================================================
# 📊 SUMMARY
# ==========================================================

Write-Output ""
Write-Output "==================================================="
Write-Output "CLEANUP SUMMARY"
Write-Output "==================================================="
Write-Output "Total Items Found     : $total"
Write-Output "Successfully Deleted  : $($Deleted.Count)"
Write-Output "Failed                : $($Failed.Count)"
Write-Output "Duration              : $($stopwatch.Elapsed.ToString())"
Write-Output "Log File              : $LogFile"
Write-Output "==================================================="
Write-Output ""
Write-Output "Cleanup complete."
