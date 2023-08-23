#!/usr/bin/env bash
#
# Restic bash wrapper for cron setup
# Currently supporting AWS S3 and Backblaze B2 as destination
#
# Do not make any modification in this script, it's maintained by Aeris Network package manager <https://repo.aerisnetwork.com/>.
#
# Karl Johnson <karljohnson.it@gmail.com>
#
# Examples:
# 
# ./backup-restic.sh -d aws -p "/backup /etc /home" | mail -s "Restic backup report for: $(hostname)" $EMAIL
# ./backup-restic.sh -d backblaze -p "/backup /etc /home" | mail -s "Restic backup report for: $(hostname)" $EMAIL

RESTIC="$(which restic)"

usage () { 
	echo "Restic bash wrapper. Currently supporting AWS S3 and Backblaze B2 as destination.";
	echo "Script usage: restic.sh -d [aws|backblaze] -p \"[each path separated with space]\"";
	exit 0;
}

while getopts :d:p:h option; do
	case "${option}" in
	d)
		DESTBACK=${OPTARG}
		[[ "$DESTBACK" == "aws" || "$DESTBACK" == "backblaze" ]] || usage
		;;
	p)
		RPATH=${OPTARG}
		;;
	h)
		usage; 
		exit;;
	\?)
		echo "Unknown option: -$OPTARG. Use -h for help." >&2
		exit 1
		;;
	:)
		echo "Missing option argument for -$OPTARG. Use -h for help." 1>&2
		exit 1
		;;
	esac
done
shift $((OPTIND-1))

if [[ -z "$RPATH" ]]; then
	echo "Missing backup path(s). Use -h for help." 1>&2
	exit 1
fi

if [[ -z "$DESTBACK" ]]; then
	echo "Missing backup destination. Use -h for help." 1>&2
	exit 1
fi

if [[ ! -f ~/.restic.cnf ]]; then
	echo "Restic config not found!"
	exit 1
else
	[[ $(stat -c %a ~/.restic.cnf) != 600 ]] && echo "Warning: restic configuration file should has 600 permission." 1>&2
	. ~/.restic.cnf
fi

if [[ -z "$RESTIC" ]]; then
	echo "Restic binary not found." && exit 1
fi

if [[ -z "$RESTIC_PASSWORD" ]]; then
	echo "Variable RESTIC_PASSWORD must be configured" && exit 1
fi

if [[ "$DESTBACK" == "aws" ]]; then
	if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
		echo "Variable AWS_ACCESS_KEY_ID must be configured" && exit 1
	fi

	if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
		echo "Variable AWS_SECRET_ACCESS_KEY must be configured" && exit 1
	fi

	if [[ -z "$AWS_DEFAULT_REGION" ]]; then
		echo "Variable AWS_DEFAULT_REGION must be configured" && exit 1
	fi
elif [[ "$DESTBACK" == "backblaze" ]]; then
	if [[ -z "$B2_ACCOUNT_ID" ]]; then
		echo "Variable B2_ACCOUNT_ID must be configured" && exit 1
	fi

	if [[ -z "$B2_ACCOUNT_KEY" ]]; then
		echo "Variable B2_ACCOUNT_KEY must be configured" && exit 1
	fi
fi

$RESTIC snapshots >/dev/null 2>&1 || { echo "This restic repository doesn't seem to be initialized" && exit 1; }

echo -e "=> Restic backup report for server: $(hostname)"

echo -e "\n==> Checking for restic update\n"
$RESTIC self-update

echo -e "\n\n==> Processing new snapshot\n"
if [[ "$DESTBACK" == "aws" ]]; then
	$RESTIC backup -o s3.storage-class=STANDARD_IA $RPATH --exclude=".cache"
elif [[ "$DESTBACK" == "backblaze" ]]; then
	$RESTIC backup -o b2.connections=8 $RPATH --exclude=".cache"
fi

echo -e "\n\n==> Cleaning old snapshots\n"
$RESTIC forget --keep-last 2 --keep-daily 7 --keep-monthly 4 --prune

echo -e "\n\n==> Your data is now stored on ${DESTBACK^^} using AES-256 encryption"
echo -e "==> Don't forget to run 'restic check' once in a while to ensure backup integrity"
