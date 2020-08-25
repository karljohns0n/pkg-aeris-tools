#!/usr/bin/env bash
#
# Restic AWS S3 bash wrapper for cron setup
#
# by Karl Johnson -- karljohnson.it@gmail.com -- kj @ Freenode
#
# Version 1.0
#

RESTIC="$(which restic)"

while getopts :p: option; do
	case "${option}" in
	p)
		RPATH=${OPTARG}
		;;
	\?)
		echo "Script usage: restic.sh -p \"[paths OR files]\"" >&2
		exit 1
		;;
	:)
		echo "Invalid option: $OPTARG requires an argument" 1>&2
		exit 1
		;;
	esac
done

if [ -z "$RPATH" ]; then
	echo "Script usage: restic.sh -p \"[paths OR files]\"" 1>&2
	exit 1
fi

if [ ! -f ~/.restic.cnf ]; then
	echo "Restic config not found!"
	exit 1
else
	. ~/.restic.cnf
fi

if [[ -z "$RESTIC" ]]; then
	echo "Restic binary not found." && exit 1
fi

if [[ -z "$RESTIC_PASSWORD" ]]; then
	echo "Variable RESTIC_PASSWORD must be configured" && exit 1
fi

if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
	echo "Variable AWS_ACCESS_KEY_ID must be configured" && exit 1
fi

if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
	echo "Variable AWS_SECRET_ACCESS_KEY must be configured" && exit 1
fi

if [[ -z "$AWS_DEFAULT_REGION" ]]; then
	echo "Variable AWS_DEFAULT_REGION must be configured" && exit 1
fi

$RESTIC snapshots >/dev/null 2>&1 || { echo "This restic repository doesn't seem to be initialized" && exit 1; }

echo -e "Processing new snapshot..\n"
$RESTIC backup -o s3.storage-class=STANDARD_IA "$RPATH" --exclude=".cache"

echo -e "\n\nCleaning old backup..\n"
$RESTIC forget --keep-last 5 --keep-monthly 1 --prune