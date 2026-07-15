#!/bin/bash
#
# Simple WP checkup for cPanel with suPHP/CGI/ruid2/cloudlinux - not mod_php (DSO)
#
# by Karl Johnson -- karljohnson.it@gmail.com -- kj @ Freenode
#
# Version 1.1
#

LOG="/tmp/cpwpcheck.txt"

rm -f $LOG

echo -e "cPanel WordPress checkup starting. Trying to find every WP on this server and:\n" 3>&1 4>&2 >>$LOG 2>&1
echo -e "- Print WP directory and version" 3>&1 4>&2 >>$LOG 2>&1
echo -e "- Chmod wp-config.php to 600 to secure file reading" 3>&1 4>&2 >>$LOG 2>&1
echo -e "\nProceeding.." 3>&1 4>&2 >>$LOG 2>&1

for vhost in $(grep DocumentRoot /usr/local/apache/conf/httpd.conf|grep "public_html\|subdomains" |awk -v vcol=2 '{print $vcol}'|sort -u); do
	find $vhost -wholename "*wp-includes/version.php" | while read wpverfile; do
		wpdir=$(echo "$wpverfile" | sed "s/\/wp-includes\/version.php//")
		echo -e "\n\nFound WP in : $wpdir" 3>&1 4>&2 >>$LOG 2>&1
		echo -e "WP version is: $(grep '^\$wp_version' "$wpverfile" | cut -d "'" -f 2)" 3>&1 4>&2 >>$LOG 2>&1
	done
	# Find wp-config independently in case it's not in the same directory as wp-includes/
	find $vhost -wholename "*wp-config.php" | while read wpconfigfile; do
		chmod 600 "$wpconfigfile"
		echo -e "Configured wp-config permissions to 600: $wpconfigfile" 3>&1 4>&2 >>$LOG 2>&1
	done
done


echo -e "Here's the log of the cPanel WordPress daily checkup for $(hostname)." | mutt -a "$LOG" -s "cPanel WordPress daily checkup report for: $(hostname)" -- $1
rm -f $LOG
rm -f /root/sent
