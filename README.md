# PostgreSQL Windows Automated Backup

PowerShell-based automation for backing up PostgreSQL databases on Windows Server. The script discovers eligible databases, saves each database as a timestamped custom-format dump, backs up PostgreSQL roles/tablespaces, writes logs, and applies a seven-day file-retention policy.

## Features

- Automatically discovers connectable, non-template databases
- Creates a separate folder for each database
- Uses PostgreSQL custom-format (`pg_dump -F c`) backups
- Backs up roles and tablespaces to a globals SQL file
- Logs success and failure messages
- Removes matching backup files older than seven days
- Designed to run through Windows Task Scheduler

## Example output

```text
F:\PostgresBackups\
├── globals_20261010_120000.sql
├── SternaService\
│   ├── SternaService_20261010_120000.dump
│   └── SternaService_20261010_180000.dump
└── vaultdemo\
    └── vaultdemo_20261010_120000.dump
```

The names and timestamps above are examples.

## Requirements

- Windows Server 2019 or compatible Windows version
- PostgreSQL client utilities matching your installation, including `pg_dump.exe`, `pg_dumpall.exe`, and `psql.exe`
- A PostgreSQL account with sufficient permissions to connect to and back up the target databases
- A Windows account that can write to the backup and log folders
- A secure PostgreSQL password-file configuration for unattended execution

## Configuration

Review `PostgreSQLBackup.ps1` before running and adjust these settings for your environment:

- `$PgBin`: PostgreSQL `bin` directory
- `$PgHost` and `$PgPort`: PostgreSQL server and port
- `$PgUser`: PostgreSQL login
- `$MaintenanceDB`: database used to discover databases
- `$BackupDir`: backup destination
- `$LogDir`: log destination

The current example excludes the database named `postgres` from individual database dumps, and excludes PostgreSQL template databases. If your `postgres` database contains application data, change the discovery query accordingly.

## Password handling

The script uses `-w` so PostgreSQL tools do not prompt interactively. Configure a PostgreSQL password file (`pgpass.conf`) for the Windows account that runs the script. Protect it with Windows ACLs.

Do **not** store passwords, `pgpass.conf`, private keys, production logs, or database backup files in Git.

## Manual test

Run PowerShell under the intended task account:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\PostgreSQLBackup.ps1"
```

Review the configured log file and confirm the expected files are created. Validate at least one backup using `pg_restore --list`, and periodically perform a test restore into a separate test database. A non-empty dump file alone does not prove that a restore will succeed.

## Schedule with Windows Task Scheduler

Create a task with a daily trigger starting at a suitable time and set it to repeat every six hours for one day.

Action:

**Program/script**
```text
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

**Arguments**
```text
-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\PostgreSQLBackup.ps1"
```

Use the same Windows account that has access to the PostgreSQL password file, script, log directory, and backup drive. Test the task with **Run** and verify the Task Scheduler result and log.

## Retention behavior

The script deletes matching `.dump` and `globals_*.sql` files older than seven days based on file modification time. It does not delete arbitrary files. Review and test retention behavior before using it for important production data.

## Limitations and operational notes

- A backup on the same server does not protect against server, disk, or ransomware failure. Maintain an additional copy on separate storage.
- The globals SQL file can contain role definitions and password hashes. Restrict access to backup files.
- This script performs logical backups; it is not a point-in-time recovery solution by itself.
- Check logs and test restores regularly.

## License

Choose and add a license file if you want others to reuse or redistribute this project.
