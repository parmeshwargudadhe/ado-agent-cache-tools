# Azure DevOps Agent Cache Tools

PowerShell scripts to **audit and clean Azure DevOps self-hosted agent caches**.  
These scripts help reclaim disk space by identifying and removing outdated task versions, .NET SDKs, runtimes, and Node.js versions.

## Scripts

### 1. audit-ado-agent-cache.ps1
Scans Azure DevOps agent directories and reports:

- ADO task versions older than a cutoff year
- .NET SDK versions < 8
- .NET shared runtimes < 8
- Node.js versions < 18

No files are deleted. This script is **safe and read-only**.

---

### 2. cleanup-ado-agent-dotnet-node-cache.ps1
Performs cleanup of items discovered during the audit.

Deletes:

- Old ADO task versions
- .NET SDK versions < 8
- .NET runtimes < 8
- Node.js versions < 18

Features:

- Discovery phase before deletion
- Displays items to be deleted
- Requires manual confirmation (`YES`)
- Progress indicator
- Detailed cleanup log file

---

## Requirements

- Windows Server / Windows
- PowerShell 5.1 or later
- Azure DevOps self-hosted agents

---

## Usage

### Run Audit

```powershell
.\audit-ado-agent-cache.ps1
```

### Run Cleanup
```powershell
.\cleanup-ado-agent-dotnet-node-cache.ps1
```
