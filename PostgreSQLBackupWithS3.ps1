
# PostgreSQL Local Backup + AWS S3 Upload
# Local backup must succeed before cloud upload begins.

$ErrorActionPreference = "Stop"

$BackupScript = "C:\Scripts\PostgreSQLBackup.ps1"
$BackupFolder = "C:\PostgresBackups" # Example: change to your local backup directory

# Replace with your own S3 bucket name before running
$BucketName = "YOUR_S3_BUCKET_NAME"
$BucketUri = "s3://$BucketName/"

$Region = "ap-south-1"
$Profile = "postgres-backup"
$LogFolder = "C:\Scripts\Logs"
$CloudLog = Join-Path $LogFolder "PostgreSQLS3Backup.log"

$WindowsPowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function Write-BackupLog {
    param([string]$Message)

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $CloudLog -Value $Line
    Write-Output $Line
}

Write-BackupLog "========== Backup workflow started =========="

try {
    if (-not (Test-Path $BackupScript)) {
        throw "Local backup script not found: $BackupScript"
    }

    if (-not (Test-Path $BackupFolder)) {
        throw "Backup folder not found: $BackupFolder"
    }

    Write-BackupLog "Starting local PostgreSQL backup."

    & $WindowsPowerShell -NoProfile -NonInteractive `
        -ExecutionPolicy Bypass -File $BackupScript

    $BackupExitCode = $LASTEXITCODE

    if ($BackupExitCode -ne 0) {
        Write-BackupLog "ERROR: Local backup failed with exit code $BackupExitCode. S3 upload skipped."
        exit 1
    }

    Write-BackupLog "Local backup succeeded. Starting S3 upload."

    & aws s3 sync $BackupFolder $BucketUri `
        --region $Region `
        --profile $Profile `
        --only-show-errors

    $UploadExitCode = $LASTEXITCODE

    if ($UploadExitCode -ne 0) {
        Write-BackupLog "ERROR: S3 upload failed with exit code $UploadExitCode."
        exit 1
    }

    Write-BackupLog "SUCCESS: S3 synchronization completed."
    Write-BackupLog "========== Backup workflow completed successfully =========="
    exit 0
}
catch {
    Write-BackupLog "ERROR: $($_.Exception.Message)"
    exit 1
}
