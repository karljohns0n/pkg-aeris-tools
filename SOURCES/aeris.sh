# Alias

## cPanel
alias apachetop="/opt/aeris/tools/apache-top.py -u http://127.0.0.1/whm-server-status"
alias apachelogs="tail -f /var/log/apache2/error_log"
alias eximlogs="tail -f /var/log/exim_mainlog"

## Git
alias gs="git status -u"

## LEMP
alias nginxlogs="tail -f /var/log/nginx/error.log"
alias purge-nginx-cache="rm -rf /var/lib/nginx/cache/fastcgi/*"

## OS
alias htop="htop -C"
alias ll="ls -alh --color=auto"
alias vi="vim"

## Node
alias megacli="/opt/megaraid/megacli"
alias storcli="/opt/megaraid/storcli"
alias stopxen="/usr/lib64/xen/bin/xendomains stop"


# MySQL

## Create MySQL DB with user and password
 
mysqladd() {
	if [ $# -ne 2 ]; then
		echo 1>&2 "Usage: mysqladd database user"
	else
		MYPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)
		MYDB=$1
		MYUSER=$2

		mysql -e "create database $MYDB;"
		mysql -e "grant all privileges on $MYDB.* to '$MYUSER'@'localhost' identified by '$MYPASS';"
		mysql -e "FLUSH PRIVILEGES;"

		echo "MySQL database $MYDB associated with user $MYUSER and password $MYPASS has been created."
	fi
}


# Let's Encrypt
alias ssl-standalone="certbot certonly --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --authenticator standalone --installer nginx --allow-subset-of-names --pre-hook \"systemctl stop monit nginx\" --post-hook \"systemctl start nginx monit\""
alias ssl-nginx="certbot certonly --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --installer nginx --allow-subset-of-names"
