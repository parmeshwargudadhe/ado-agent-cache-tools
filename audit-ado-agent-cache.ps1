Write-Output "Starting Azure DevOps agent cache audit..."
Write-Output "==================================================="

# 🔹 Hardcoded cutoff year
$TaskCutoffYear = 2024

$AgentHomes = @(
    "C:\agent",
    "E:\agent5",
    "E:\agent6",
    "E:\agent7",
    "E:\agent8",
    "E:\agent9",
    "E:\agent10",
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

$GrandTotal = 0

foreach ($AgentHome in $AgentHomes) {

    $WorkDir = Join-Path $AgentHome "_work"
    if (-not (Test-Path $WorkDir)) { continue }

    $AgentCount = 0

    Write-Output ""
    Write-Output "============================================="
    Write-Output "Agent: $AgentHome"
    Write-Output "============================================="

    # ==========================================================
    # 1️⃣ ADO Task Versions older than cutoff year
    # ==========================================================
    $TasksDir = Join-Path $WorkDir "_tasks"

    if (Test-Path $TasksDir) {

        Write-Output "`n--- ADO Task Versions older than $TaskCutoffYear ---"

        $OldTaskItems = @()

        Get-ChildItem $TasksDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {

            $TaskFolder = $_.FullName

            # Version folders
            Get-ChildItem $TaskFolder -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime.Year -lt $TaskCutoffYear } |
            ForEach-Object { $OldTaskItems += $_ }

            # Associated marker files (.completed, .node6, etc.)
            Get-ChildItem $TaskFolder -File -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Extension -match '\.completed|\.node') -and
                $_.CreationTime.Year -lt $TaskCutoffYear
            } |
            ForEach-Object { $OldTaskItems += $_ }
        }

        if ($OldTaskItems.Count -gt 0) {
            $OldTaskItems |
            Select-Object FullName, CreationTime |
            Format-Table -AutoSize

            $AgentCount += $OldTaskItems.Count
        }
        else {
            Write-Output "(none)"
        }
    }

    # ==========================================================
    # 2️⃣ .NET SDK < 8 (folders + .complete files)
    # ==========================================================
    $DotnetSdkDir = Join-Path $WorkDir "_tool\dotnet\sdk"

    if (Test-Path $DotnetSdkDir) {

        Write-Output "`n--- .NET SDK versions < 8 (Folders) ---"

        $OldSdkFolders = Get-ChildItem $DotnetSdkDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $major = Get-MajorVersion $_.Name
            $major -and $major -lt 8
        }

        if ($OldSdkFolders) {
            $OldSdkFolders |
            Select-Object FullName |
            Format-Table -AutoSize

            $AgentCount += $OldSdkFolders.Count
        }
        else {
            Write-Output "(none)"
        }

        Write-Output "`n--- .NET SDK versions < 8 (.complete files) ---"

        $OldSdkComplete = Get-ChildItem $DotnetSdkDir -File -Filter "*.complete" -ErrorAction SilentlyContinue |
        Where-Object {
            $major = Get-MajorVersion $_.BaseName
            $major -and $major -lt 8
        }

        if ($OldSdkComplete) {
            $OldSdkComplete |
            Select-Object FullName |
            Format-Table -AutoSize

            $AgentCount += $OldSdkComplete.Count
        }
        else {
            Write-Output "(none)"
        }
    }

    # ==========================================================
    # 3️⃣ Shared Runtimes < 8
    # ==========================================================
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

                Write-Output "`n--- $runtime versions < 8 ---"

                $OldRuntime = Get-ChildItem $RuntimePath -Directory -ErrorAction SilentlyContinue |
                Where-Object {
                    $major = Get-MajorVersion $_.Name
                    $major -and $major -lt 8
                }

                if ($OldRuntime) {
                    $OldRuntime |
                    Select-Object FullName |
                    Format-Table -AutoSize

                    $AgentCount += $OldRuntime.Count
                }
                else {
                    Write-Output "(none)"
                }
            }
        }
    }

    # ==========================================================
    # 4️⃣ Node < 18
    # ==========================================================
    $NodeDir = Join-Path $WorkDir "_tool\node"

    if (Test-Path $NodeDir) {

        Write-Output "`n--- Node versions < 18 ---"

        $OldNodes = Get-ChildItem $NodeDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $major = Get-MajorVersion $_.Name
            $major -and $major -lt 18
        }

        if ($OldNodes) {
            $OldNodes |
            Select-Object FullName |
            Format-Table -AutoSize

            $AgentCount += $OldNodes.Count
        }
        else {
            Write-Output "(none)"
        }
    }

    Write-Output "`nTotal items identified for this agent: $AgentCount"
    $GrandTotal += $AgentCount
}

Write-Output ""
Write-Output "==================================================="
Write-Output "GRAND TOTAL items identified across all agents: $GrandTotal"
Write-Output "==================================================="
Write-Output ""
Write-Output "Audit complete. No files were deleted."
