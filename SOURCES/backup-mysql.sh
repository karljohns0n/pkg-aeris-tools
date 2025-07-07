#!/usr/bin/env bash
#
# backup-mysql.sh - Version 1.6.0
# Copyright (C) Karl Johnson - karljohnson.it@gmail.com
#
# SQL Backup and Optimize - All Databases
# Number of extra backup retention days can be configured with argument -d INTEGER
# This script should be configured as a daily cron
# Tested up to MariaDB 11.4
# Do not make any modification to this script, it's maintained by Aeris Network <https://repo.aerisnetwork.com/>
#
# Examples:
#
# ./backup-mysql.sh -d 2
# ./backup-mysql.sh -d 7 --no-check
# ./backup-mysql.sh -d 7 --optimize --analyze

set -euo pipefail
trap 'echo "ERROR on line $LINENO — exiting." >&2' ERR

### System Setup

BACKUP=/backup/databases
GZIP=$(command -v gzip)
NOW=$(date +"%Y-%m-%d")
RDAY="0"
SQLCHECK="TRUE"
OPTIMIZE=""
ANALYZE=""

MUSER="root"
MHOST="localhost"

while [ $# -gt 0 ]; do
    case $1 in
        -d )    shift
                RDAY=$1
                ;;
        --check ) SQLCHECK="TRUE"
                ;;
        --no-check ) SQLCHECK="FALSE"
                ;;
        --optimize ) OPTIMIZE="--optimize"
                ;;
        --analyze ) ANALYZE="TRUE"
                ;;
        * )     echo "Invalid option: $1"
                echo "Script usage: $(basename $0) [--check|--no-check] [--optimize] [--analyze] [-d number of days]" >&2
                exit 1
    esac
    shift
done

if [[ ! "$RDAY" =~ ^[0-9]+$ ]]; then 
    echo "ERROR: Number of extra retention days must be an integer" >&2
    exit 1
fi

if [ ! -f /root/.my.cnf ]; then
    echo "ERROR: SQL client config /root/.my.cnf not found!" >&2
    exit 1
fi

if [ ! -d "$BACKUP" ] 
then
    mkdir -p "$BACKUP"
    chmod 700 "$BACKUP"
fi

if command -v mysql >/dev/null 2>&1; then
    SQLBIN=$(command -v mysql)
elif command -v mariadb >/dev/null 2>&1; then
    SQLBIN=$(command -v mariadb)
else
    echo "ERROR: No mysql or mariadb client found in PATH." >&2
    exit 1
fi

if command -v mysqldump >/dev/null 2>&1; then
    SQLDUMP=$(command -v mysqldump)
elif command -v mariadb-dump >/dev/null 2>&1; then
    SQLDUMP=$(command -v mariadb-dump)
else
    echo "ERROR: No mysqldump or mariadb-dump found in PATH." >&2
    exit 1
fi

if command -v mysqlcheck >/dev/null 2>&1; then
    SQLCHECK_BIN=$(command -v mysqlcheck)
elif command -v mariadb-check >/dev/null 2>&1; then
    SQLCHECK_BIN=$(command -v mariadb-check)
else
    echo "ERROR: No mysqlcheck or mariadb-check found in PATH." >&2
    exit 1
fi

### Cleanup Directory

echo -e "\nPruning SQL Backup...\n"
find "$BACKUP" -maxdepth 1 -type f -name "*.gz" -daystart -mtime +"$RDAY" -exec rm -f {} \;
echo -e "\nCompleted.\n"

### Start SQL Backup

echo -e "\nStarting SQL Backup...\n"
DBS="$("$SQLBIN" --defaults-extra-file=/root/.my.cnf -u "$MUSER" -h "$MHOST" -Bse 'SHOW DATABASES')"
for db in $DBS; do
	FILE="$BACKUP/mysql-$db.$NOW.$(date +"%H-%M-%S").gz"
	"$SQLDUMP" --defaults-extra-file=/root/.my.cnf -u "$MUSER" -h "$MHOST" --force --single-transaction "$db" | "$GZIP" -9 > "$FILE"
done
echo -e "\nCompleted.\n"

### Check SQL databases if requested

echo -e "\nStarting SQL Check...\n"
if [ "$SQLCHECK" = "TRUE" ]; then
    "$SQLCHECK_BIN" --defaults-extra-file=/root/.my.cnf -u "$MUSER" $OPTIMIZE --auto-repair --all-databases
fi
echo -e "\nCompleted.\n"

### Perform SQL Analyze if requested

echo -e "\nStarting SQL Analyze...\n"
if [ "$ANALYZE" = "TRUE" ]; then
    for alldbs in $("$SQLBIN" --defaults-extra-file=/root/.my.cnf -e 'SHOW DATABASES' -s --skip-column-names | grep -vE '^(information_schema|performance_schema|mysql|sys)$'); do
        for alltbl in $("$SQLBIN" --defaults-extra-file=/root/.my.cnf "$alldbs" -sNe 'SHOW TABLES'); do
            "$SQLBIN" --defaults-extra-file=/root/.my.cnf "$alldbs" -e "ANALYZE TABLE $alltbl;"
        done
    done
fi
echo -e "\nCompleted.\n"
