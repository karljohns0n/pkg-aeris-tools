#!/usr/bin/env bash
#
# backup-mysql.sh - Version 1.5.0
# Copyright (C) Karl Johnson - karljohnson.it@gmail.com
#
# SQL Backup and Optimize - All Databases
# Number of extra backup retention days can be configured with argument -d INTEGER
# This script should be configured as a daily cron
# Tested up to MariaDB 10.11
# Do not make any modification to this script, it's maintained by Aeris Network <https://repo.aerisnetwork.com/>
#
# Examples:
#
# ./backup-mysql.sh -d 2
# ./backup-mysql.sh -d 7 --no-check
# ./backup-mysql.sh -d 7 --optimize --analyze

### System Setup

BACKUP=/backup/databases
NOW=$(date +"%Y-%m-%d")
RDAY="0"
MYSQLCHECK="TRUE"
OPTIMIZE=""
ANALYZE=""

while [ "$1" != "" ]; do
    case $1 in
        -d )    shift
                RDAY=$1
                ;;
        --check ) MYSQLCHECK="TRUE"
                ;;
        --no-check ) MYSQLCHECK="FALSE"
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
    echo "Number of extra retention days must be an integer"
    exit 1
fi

if [ ! -f /root/.my.cnf ]; then
    echo "MySQL client config not found!"
    exit 1
fi

if [ ! -d $BACKUP ] 
then
    mkdir -p $BACKUP
fi

### SQL Setup

MUSER="root"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"

### Cleanup Directory

echo -e "\nPruning SQL Backup...\n"
find $BACKUP -maxdepth 1 -type f -name "*.gz" -daystart -mtime +"$RDAY" -exec rm -f {} \;
echo -e "\nCompleted.\n"

### Start SQL Backup

echo -e "\nStarting SQL Backup...\n"
DBS="$($MYSQL --defaults-extra-file=/root/.my.cnf -u $MUSER -h $MHOST -Bse 'show databases')"
for db in $DBS; do
	FILE=$BACKUP/mysql-$db.$NOW.$(date +"%H-%M-%S").gz
	$MYSQLDUMP --defaults-extra-file=/root/.my.cnf -u $MUSER -h $MHOST --force --single-transaction $db | $GZIP -9 > $FILE
done
echo -e "\nCompleted.\n"

### Check SQL databases if requested

echo -e "\nStarting SQL Check...\n"
if [ "$MYSQLCHECK" = "TRUE" ]; then
    /usr/bin/mysqlcheck --defaults-extra-file=/root/.my.cnf -u root $OPTIMIZE --auto-repair --all-databases
fi
echo -e "\nCompleted.\n"

### Perform SQL Analyze if requested

echo -e "\nStarting SQL Analyze...\n"
if [ "$ANALYZE" = "TRUE" ]; then
    for alldbs in $(mysql --defaults-extra-file=/root/.my.cnf -e 'show databases' -s --skip-column-names); do 
        for alltbl in $(mysql --defaults-extra-file=/root/.my.cnf "$alldbs" -sNe 'show tables'); do 
            mysql --defaults-extra-file=/root/.my.cnf "$alldbs" -e "ANALYZE TABLE $alltbl PERSISTENT FOR ALL;"
        done
    done
fi
echo -e "\nCompleted.\n"
