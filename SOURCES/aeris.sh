# Alias

## cPanel
alias apachetop="/opt/aeris/tools/apache-top.py -u http://127.0.0.1/whm-server-status"
alias apachelogs="tail -f /var/log/apache2/error_log"
alias eximlogs="tail -f /var/log/exim_mainlog"

## Git
alias gs="git status -u"

## Hypervisor
alias megacli="/opt/megaraid/megacli"
alias storcli="/opt/megaraid/storcli"
alias xenstop="/usr/lib64/xen/bin/xendomains stop"

## LEMP
alias nginxlogs="tail -f /var/log/nginx/error.log"
alias purge-nginx-cache="rm -rf /var/lib/nginx/cache/fastcgi/*"

## OS
alias htop="htop -C"
alias ll="ls -alh --color=auto"
alias vi="vim"

## Other
alias ttfb="curl -s -o /dev/null -w 'Connect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal time: %{time_total}s \n'"


# MySQL

## Create MySQL DB with user and password
 
mysqladd() {
	if [[ $# -ne 2 ]]; then
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

## SSL generation with standalone, nginx plugin or wildcard using DNS

alias ssl-standalone="certbot certonly --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --authenticator standalone --installer nginx --allow-subset-of-names --pre-hook \"systemctl stop monit nginx\" --post-hook \"systemctl start nginx monit\""
alias ssl-nginx="certbot certonly --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --installer nginx --allow-subset-of-names"

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

		certbot certonly --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --debug-challenges "$@"
	fi
}

ssl-check() {
	if [[ $# -ne 1 ]]; then
		echo 1>&2 "Usage: ssl-check example.com"
	else
		echo | openssl s_client -servername "$1" -connect "$1":443 2>/dev/null | openssl x509 -noout -subject -dates
	fi
}