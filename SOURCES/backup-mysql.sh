#!/usr/bin/env bash
#
# backup-mysql.sh - Version 1.7.0
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

if command -v mariadb >/dev/null 2>&1; then
    SQLBIN=$(command -v mariadb)
elif command -v mysql >/dev/null 2>&1; then
    SQLBIN=$(command -v mysql)
else
    echo "ERROR: No mariadb or mysql client found in PATH." >&2
    exit 1
fi

if command -v mariadb-dump >/dev/null 2>&1; then
    SQLDUMP=$(command -v mariadb-dump)
elif command -v mysqldump >/dev/null 2>&1; then
    SQLDUMP=$(command -v mysqldump)
else
    echo "ERROR: No mariadb-dump or mysqldump found in PATH." >&2
    exit 1
fi

if command -v mariadb-check >/dev/null 2>&1; then
    SQLCHECK_BIN=$(command -v mariadb-check)
elif command -v mysqlcheck >/dev/null 2>&1; then
    SQLCHECK_BIN=$(command -v mysqlcheck)
else
    echo "ERROR: No mariadb-check or mysqlcheck found in PATH." >&2
    exit 1
fi

### Cleanup Directory

echo -e "\nPruning SQL Backup (keeping $RDAY day(s))...\n"
find "$BACKUP" -maxdepth 1 -type f -name "*.gz" -daystart -mtime +"$RDAY" -exec rm -f {} \;
echo -e "\nCompleted.\n"

### Start SQL Backup

echo -e "\nStarting SQL Backup...\n"
EXCLUDE_DBS="information_schema|performance_schema|mysql|sys"
DBS="$("$SQLBIN" --defaults-extra-file=/root/.my.cnf -u "$MUSER" -h "$MHOST" -Bse 'SHOW DATABASES' | grep -vE "^($EXCLUDE_DBS)$")"
DB_COUNT=$(echo "$DBS" | wc -w)
DB_CURRENT=0
for db in $DBS; do
	DB_CURRENT=$((DB_CURRENT + 1))
	echo "[$DB_CURRENT/$DB_COUNT] Dumping $db..."
	FILE="$BACKUP/mysql-$db.$NOW.$(date +"%H-%M-%S").gz"
	# Disable errexit and pipefail in subshell so --force works properly, use PIPESTATUS to check dump exit code
	( set +e +o pipefail; "$SQLDUMP" --defaults-extra-file=/root/.my.cnf -u "$MUSER" -h "$MHOST" --force --single-transaction --routines --triggers --events "$db" | "$GZIP" -9 > "$FILE"; exit "${PIPESTATUS[0]}" ) || echo "Warning: Issues encountered while dumping $db (continuing with --force)"
done
echo -e "\nCompleted.\n"

### Check SQL databases if requested

if [ "$SQLCHECK" = "TRUE" ]; then
    echo -e "\nStarting SQL Check...\n"
    "$SQLCHECK_BIN" --defaults-extra-file=/root/.my.cnf -u "$MUSER" ${OPTIMIZE:+"$OPTIMIZE"} --auto-repair --all-databases
    echo -e "\nCompleted.\n"
fi

### Perform SQL Analyze if requested

if [ "$ANALYZE" = "TRUE" ]; then
    echo -e "\nStarting SQL Analyze...\n"
    for alldbs in $("$SQLBIN" --defaults-extra-file=/root/.my.cnf -e 'SHOW DATABASES' -s --skip-column-names | grep -vE "^($EXCLUDE_DBS)$"); do
        for alltbl in $("$SQLBIN" --defaults-extra-file=/root/.my.cnf "$alldbs" -sNe 'SHOW TABLES'); do
            "$SQLBIN" --defaults-extra-file=/root/.my.cnf "$alldbs" -e "ANALYZE TABLE \`$alltbl\`;"
        done
    done
    echo -e "\nCompleted.\n"
fi
