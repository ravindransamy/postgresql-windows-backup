# PostgreSQL 17 Automated Backup for Windows Server
# Discovers application databases automatically, backs them up individually,
# saves globals (roles/tablespaces), and removes managed backup files older than 7 days.
#
# Configure these values for your environment before use.

$ErrorActionPreference = "Stop"

# PostgreSQL connection settings
$PgBin         = "C:\Program Files\PostgreSQL\17\bin"
$PgHost        = "localhost"
$PgPort        = "5432"
$PgUser        = "postgres"
$MaintenanceDB = "postgres"

# Backup and log locations
$BackupDir = "F:\PostgresBackups"
$LogDir    = "C:\Scripts\Logs"
$LogFile   = Join-Path $LogDir "PostgreSQLBackup.log"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RunFailed = $false

function Write-Log {
    param([string]$Message)
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -LiteralPath $LogFile -Value $Line
    Write-Output $Line
}

try {
    New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null

    $PgDump    = Join-Path $PgBin "pg_dump.exe"
    $Psql      = Join-Path $PgBin "psql.exe"
    $PgDumpAll = Join-Path $PgBin "pg_dumpall.exe"

    foreach ($Exe in @($PgDump, $Psql, $PgDumpAll)) {
        if (-not (Test-Path -LiteralPath $Exe)) {
            throw "PostgreSQL utility not found: $Exe"
        }
    }

    Write-Log "========== Backup started =========="

    # Discover connectable, non-template databases. The maintenance database
    # 'postgres' is excluded from individual database dumps.
    $DbQuery = @"
SELECT datname
FROM pg_database
WHERE datistemplate = false
  AND datallowconn = true
  AND datname <> 'postgres'
ORDER BY datname;
"@

    $DbOutput = @(
        & $Psql -X -w -h $PgHost -p $PgPort -U $PgUser -d $MaintenanceDB `
            -A -t -v ON_ERROR_STOP=1 -c $DbQuery 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Database discovery failed: $($DbOutput -join ' ')"
    }

    $Databases = @(
        $DbOutput |
        ForEach-Object { "$_".Trim() } |
        Where-Object { $_ -ne "" }
    )

    if ($Databases.Count -eq 0) {
        throw "No application databases discovered."
    }

    Write-Log "Discovered $($Databases.Count) application database(s)."

    # Back up roles and tablespaces.
    $GlobalsFile = Join-Path $BackupDir "globals_$Timestamp.sql"
    $ConnectionString = "host=$PgHost port=$PgPort user=$PgUser dbname=$MaintenanceDB"

    & $PgDumpAll -w -d $ConnectionString --globals-only -f $GlobalsFile 2>&1 |
        ForEach-Object { Write-Log "$_" }

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath $GlobalsFile) -or
        (Get-Item -LiteralPath $GlobalsFile).Length -eq 0) {

        Remove-Item -LiteralPath $GlobalsFile -Force -ErrorAction SilentlyContinue
        Write-Log "FAILED: PostgreSQL roles/tablespaces backup."
        $RunFailed = $true
    }
    else {
        Write-Log "SUCCESS: PostgreSQL roles/tablespaces."
    }

    # Back up every discovered application database into its own folder.
    foreach ($Database in $Databases) {
        $SafeName = $Database -replace '[^A-Za-z0-9_.-]', '_'
        $DatabaseDir = Join-Path $BackupDir $SafeName
        New-Item -ItemType Directory -Force -Path $DatabaseDir | Out-Null

        $BackupFile = Join-Path $DatabaseDir "${SafeName}_${Timestamp}.dump"
        Write-Log "Starting database backup: $Database"

        & $PgDump -w -h $PgHost -p $PgPort -U $PgUser -d $Database `
            -F c -f $BackupFile 2>&1 |
            ForEach-Object { Write-Log "$_" }

        if ($LASTEXITCODE -eq 0 -and
            (Test-Path -LiteralPath $BackupFile) -and
            (Get-Item -LiteralPath $BackupFile).Length -gt 0) {

            Write-Log "SUCCESS: $Database -> $BackupFile"
        }
        else {
            Remove-Item -LiteralPath $BackupFile -Force -ErrorAction SilentlyContinue
            Write-Log "FAILED: $Database"
            $RunFailed = $true
        }
    }

    # Remove only backup files matching this script's naming convention that
    # are older than seven days. Cleanup runs after the backup attempts.
    $Cutoff = (Get-Date).AddDays(-7)

    Get-ChildItem -LiteralPath $BackupDir -File -Recurse |
        Where-Object {
            $_.LastWriteTime -lt $Cutoff -and
            (
                $_.Name -match '^[A-Za-z0-9_.-]+_\d{8}_\d{6}\.dump$' -or
                $_.Name -match '^globals_\d{8}_\d{6}\.sql$'
            )
        } |
        ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Force
                Write-Log "RETENTION: Deleted $($_.FullName)"
            }
            catch {
                Write-Log "RETENTION FAILED: $($_.FullName) - $($_.Exception.Message)"
                $RunFailed = $true
            }
        }

    if ($RunFailed) {
        Write-Log "Backup run completed with failures."
        exit 1
    }

    Write-Log "All backups completed successfully."
    exit 0
}
catch {
    $ErrorMessage = $_.Exception.Message
    try {
        Write-Log "FATAL ERROR: $ErrorMessage"
    }
    catch {
        Write-Error $ErrorMessage
    }
    exit 1
}
