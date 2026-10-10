\# PostgreSQL Windows Backup Automation with AWS S3



PowerShell-based automation for backing up PostgreSQL databases on Windows and optionally copying successful backups to Amazon S3.



\## Features



\- Automatically discovers eligible PostgreSQL databases.

\- Creates timestamped custom-format database dumps using `pg\_dump`.

\- Exports PostgreSQL roles and tablespaces.

\- Organizes backups into separate database folders.

\- Logs backup success and failure.

\- Removes managed local backup files older than seven days.

\- Supports AWS S3 synchronization after successful local backups.

\- Supports S3 lifecycle policies for cloud retention.

\- Designed for Windows Task Scheduler.



\## Architecture



Windows Task Scheduler → PowerShell backup script → PostgreSQL backups → AWS CLI → Amazon S3



The cloud wrapper uploads files only after the local backup script returns success.



\## Requirements



\- Windows Server 2019 or a compatible Windows version.

\- PostgreSQL client utilities: `pg\_dump.exe`, `pg\_dumpall.exe`, and `psql.exe`.

\- A PostgreSQL account with appropriate backup permissions.

\- A Windows account with access to the backup and log directories.

\- AWS CLI v2 for S3 uploads.

\- An AWS CLI profile with least-privilege permissions for the target bucket.

\- An S3 bucket configured with appropriate access controls and lifecycle retention.



\## Project Files



\- `PostgreSQLBackup.ps1` — local PostgreSQL backup and retention.

\- `PostgreSQLBackupWithS3.ps1` — local backup orchestration and S3 synchronization.

\- `.gitignore` — excludes backup data, logs, and common credential files.



\## Configuration



Review `PostgreSQLBackup.ps1` and configure the PostgreSQL installation path, connection settings, backup directory, and log directory for your environment.



For `PostgreSQLBackupWithS3.ps1`, configure:



\- `$BackupScript` — location of the local backup script.

\- `$BackupFolder` — local directory containing the backup files.

\- `$BucketName` — your private S3 bucket name.

\- `$Region` — AWS region where the bucket exists.

\- `$Profile` — AWS CLI profile configured for the backup task.

\- `$LogFolder` — log directory.



The example configuration contains placeholders. Replace them with your own values before running the scripts.



\## Secure Credential Handling



\- Do not hard-code AWS access keys or PostgreSQL passwords.

\- Do not commit AWS credential files, `pgpass.conf`, private keys, or tokens.

\- Use a dedicated IAM identity with only the required S3 permissions.

\- Keep the S3 bucket private and block public access.

\- Protect local credential files using Windows ACLs.

\- Never commit database dumps, globals exports, or production logs.



\## Manual Execution



Run PowerShell under the Windows account configured for the backup workflow.



Local backup:



```powershell

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Scripts\\PostgreSQLBackup.ps1"

```



Combined local backup and S3 upload:



```powershell

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Scripts\\PostgreSQLBackupWithS3.ps1"

```



Confirm that the local backup succeeds before checking the S3 destination.



\## AWS S3 Verification



List the objects in your configured bucket:



```powershell

aws s3 ls s3://YOUR\_S3\_BUCKET\_NAME/ --recursive --region YOUR\_AWS\_REGION --profile YOUR\_AWS\_PROFILE

```



Replace the example values with your own configuration. Do not publish credentials or production backup data.



\## Scheduling



Configure Windows Task Scheduler with a daily trigger that repeats every six hours for one day.



Use the combined wrapper as the action when cloud upload is required. Run the task under the Windows account that has access to the backup files and AWS CLI profile.



Test the scheduled task manually and review its logs and exit status.



\## Retention



The local backup script removes matching managed backup files older than seven days.



Cloud retention is configured separately through an S3 Lifecycle rule. Configure the lifecycle expiration period to meet your retention requirements and review versioning settings if enabled.



Lifecycle expiration is asynchronous; objects may not disappear exactly when the configured age is reached.



\## Recovery and Validation



Validate custom-format backups using `pg\_restore --list` and periodically perform a test restore into a separate test database.



A successful upload does not by itself prove that a database can be restored. Protect the globals SQL file because it may contain role definitions and password hashes.



\## Limitations



\- Logical backups are not a point-in-time recovery solution by themselves.

\- Backups stored only on the source server do not protect against server or disk failure.

\- AWS usage may incur charges depending on the account, credits, region, storage, and requests.

\- Test recovery procedures before relying on backups for disaster recovery.



\## License



Add a license file if you intend to permit others to reuse or redistribute this project.
