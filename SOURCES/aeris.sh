# aeris.sh - Version 1.10.0
# Copyright (C) Karl Johnson - karljohnson.it@gmail.com
# Do not make any modification to this script, it's maintained by Aeris Network <https://repo.aerisnetwork.com/>
#

HISTSIZE=10000

# Alias

## cPanel
alias apachetop="/opt/aeris/tools/apache-top.py -u http://127.0.0.1/whm-server-status"
alias apachetop2="/opt/aeris/tools/apache-top2.py -u http://127.0.0.1/whm-server-status"
alias apachelogs="tail -f /var/log/apache2/error_log"
alias eximlogs="tail -f /var/log/exim_mainlog"
alias nginxlogs="tail -f /var/log/nginx/error.log"

## Dev
alias gs="git status -u"
alias pa="php artisan"

## Hypervisor
alias dc="docker compose"
alias megacli="/opt/megaraid/megacli"
alias storcli="/opt/megaraid/storcli"
alias xenstop="/usr/lib64/xen/bin/xendomains stop"

## LEMP
alias purge-nginx-cache="rm -rf /var/lib/nginx/cache/fastcgi/*"

## OS
alias clear-history="cat /dev/null > ~/.bash_history ; history -c"
alias htop="htop -C"
alias ll="ls -alh --color=auto"
alias tailf="tail -f"
alias vi="vim"

## Other
alias ttfb="curl -s -o /dev/null -w 'Connect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal time: %{time_total}s \n'"
alias yabs="/opt/aeris/tools/yabs.sh -r56"

# MySQL/MariaDB

get_sql_bin() {
	local type=$1
	
	case $type in
		"client")
			if command -v mysql >/dev/null 2>&1; then
				echo "mysql"
			elif command -v mariadb >/dev/null 2>&1; then
				echo "mariadb"
			else
				echo "Error: Neither mysql nor mariadb client found" >&2
				return 1
			fi
			;;
		"check")
			if command -v mysqlcheck >/dev/null 2>&1; then
				echo "mysqlcheck"
			elif command -v mariadbcheck >/dev/null 2>&1; then
				echo "mariadbcheck"
			else
				echo "Error: Neither mysqlcheck nor mariadbcheck found" >&2
				return 1
			fi
			;;
		*)
			echo "Error: Invalid type. Use 'client' or 'check'" >&2
			return 1
			;;
	esac
}

## Create MySQL/MariaDB DB with user and password
 
mysql-add() {
	if [[ $# -ne 2 ]]; then
		echo 1>&2 "Usage: mysql-add database user"
	else
		SQL_BIN=$(get_sql_bin client) || return 1
		SQLPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)
		SQLDB=$1
		SQLUSER=$2

		$SQL_BIN -e "CREATE DATABASE $SQLDB;"
		$SQL_BIN -e "GRANT ALL PRIVILEGES ON $SQLDB.* TO '$SQLUSER'@'localhost' IDENTIFIED BY '$SQLPASS';"
		$SQL_BIN -e "FLUSH PRIVILEGES;"

		echo "MySQL/MariaDB database $SQLDB associated with user $SQLUSER and password $SQLPASS has been created."
	fi
}

## Optimize all databases

mysql-optimize() {
	SQL_BIN=$(get_sql_bin client) || return 1
	SQLCHECK_BIN=$(get_sql_bin check) || return 1
	
	$SQLCHECK_BIN --defaults-extra-file=/root/.my.cnf -u root --auto-repair --optimize --all-databases
}


# Let's Encrypt

## SSL generation with standalone, nginx plugin or wildcard using DNS

alias ssl-standalone="certbot certonly --agree-tos --register-unsafely-without-email --key-type ecdsa --authenticator standalone --installer nginx --allow-subset-of-names --pre-hook \"systemctl stop monit nginx\" --post-hook \"systemctl start nginx monit\""
alias ssl-nginx="certbot certonly --agree-tos --register-unsafely-without-email --nginx --key-type ecdsa --allow-subset-of-names"

ssl-wildcard() {
	if [[ $# -lt 1 ]]; then
		echo 1>&2 "Usage: ssl-wildcard -d *.example.com -d example.com"
	else
		if [[ ! -d /etc/letsencrypt || ! -f /usr/bin/certbot ]]; then
			echo "Cerbot isn't installed, installing.."
			yum -q -y install certbot-nginx
		fi

		if [[ ! -f /etc/letsencrypt/acme-dns-auth.py ]]; then
			echo "ACME DNS authentication hook script isn't available, downloading.."
			curl -s -o /etc/letsencrypt/acme-dns-auth.py https://raw.githubusercontent.com/joohoi/acme-dns-certbot-joohoi/master/acme-dns-auth.py
			chmod 0700 /etc/letsencrypt/acme-dns-auth.py
		fi

		certbot certonly --agree-tos --register-unsafely-without-email --key-type ecdsa --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --debug-challenges "$@"
	fi
}

ssl-check() {
	if [[ $# -ne 1 ]]; then
		echo 1>&2 "Usage: ssl-check example.com"
	else
		echo | openssl s_client -servername "$1" -connect "$1":443 2>/dev/null | openssl x509 -noout -subject -dates
	fi
}

# PHP-FPM

## Add FPM pool for a new user

phpfpmadd() {
	if [[ $# -ne 1 ]]; then
		echo 1>&2 "Usage: phpfpmadd user"
	else
		if [[ ! -f /etc/php-fpm.d/www.conf ]]; then
			echo 1>&2 "Default www PHP pool is needed."
		else
			FPMPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)
			FPMUSER=$1

			adduser -b /home "$FPMUSER"
			chmod 750 /home/"$FPMUSER"
			chown "$FPMUSER":nginx /home/"$FPMUSER"
			echo "$FPMPASS" | passwd "$FPMUSER" --stdin
			cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/"$FPMUSER".conf
			sed -i "s/\[www\]/\[$FPMUSER\]/g" /etc/php-fpm.d/"$FPMUSER".conf
			sed -i "/^user\ \=/c\user = $FPMUSER" /etc/php-fpm.d/"$FPMUSER".conf
			sed -i "/^group\ \=/c\group = $FPMUSER" /etc/php-fpm.d/"$FPMUSER".conf
			sed -i "/^listen\ \=/c\listen\ \=\ \/run\/php\-fpm\/$FPMUSER.sock" /etc/php-fpm.d/"$FPMUSER".conf
			sed -i "/listen.owner\ \=/c\listen.owner\ \=\ nginx" /etc/php-fpm.d/"$FPMUSER".conf
			sed -i "/listen.group\ \=/c\listen.group\ \=\ $FPMUSER" /etc/php-fpm.d/"$FPMUSER".conf
			echo "New user and PHP pool $FPMUSER has been created with password $FPMPASS."
		fi
	fi
}

# GoAccess

goaccess-live() {
	goid=$(openssl rand -hex 10)
	echo "Link: http://$(hostname)/$goid.html" ; goaccess /var/log/nginx/*-access_log -o /usr/share/nginx/html/"$goid".html --real-time-html ; rm -fv /usr/share/nginx/html/"$goid".html
}

goaccess-all() {
	goid=$(openssl rand -hex 10)
	echo "Link: http://$(hostname)/$goid.html" ; zcat -f /var/log/nginx/*-access_log* | goaccess -o /usr/share/nginx/html/"$goid".html --real-time-html ; rm -fv /usr/share/nginx/html/"$goid".html
}
