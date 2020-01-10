#!/bin/bash
#
# MySQL Backup and Optimize - All Databases
# Number of extra backup retention days can be configured with argument -d INTEGER
# This script should be configured as a daily cron
#
# by Karl Johnson -- karljohnson.it@gmail.com -- kj @ Freenode
#
# Version 1.3
#

### System Setup ###

BACKUP=/backup/databases
NOW=$(date +"%Y-%m-%d")
RDAY="0"

while getopts :d: option; do
	case "${option}" in
	d) 
		RDAY=${OPTARG}
		;;
	\?)
		echo "script usage: backup-mysql.sh [-d number of days]" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an integer." >&2
		exit 1
		;;
	esac
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

### MySQL Setup ###

MUSER="root"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"

### Cleanup Directory ###

find $BACKUP -maxdepth 1 -type f -name "*.gz" -daystart -mtime +"$RDAY" -exec rm -f {} \;

### Start MySQL Backup ###

DBS="$($MYSQL --defaults-extra-file=/root/.my.cnf -u $MUSER -h $MHOST -Bse 'show databases')"
for db in $DBS; do
	FILE=$BACKUP/mysql-$db.$NOW.$(date +"%H-%M-%S").gz
	$MYSQLDUMP --defaults-extra-file=/root/.my.cnf -u $MUSER -h $MHOST --single-transaction $db | $GZIP -9 > $FILE
done

### Optimize databases at the same time ###

/usr/bin/mysqlcheck --defaults-extra-file=/root/.my.cnf -u root --auto-repair --optimize --all-databases