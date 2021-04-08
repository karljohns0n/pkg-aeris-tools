# Aeris Tools

[![ProjectStatus](https://img.shields.io/badge/status-active-brightgreen.svg)](#)
[![Build](https://img.shields.io/travis/com/karljohns0n/pkg-aeris-tools/master.svg)](https://travis-ci.com/karljohns0n/pkg-aeris-tools)
[![Release 1.10-5](https://img.shields.io/badge/release-1.10--5-success.svg)](#)
[![Change Log](https://img.shields.io/badge/change-log-blue.svg?style=flat)](https://repo.aerisnetwork.com/stable/centos/6/x86_64/repoview/aeris-tools.html)

## Synopsis

This package provides a set of tools and scripts for Web hosting servers from different vendors including Aeris Network.

## Tools

### Scripts

* apache-top.py (2018)
* archivecheck.sh (1.1)
* backup-mysql.sh (1.4)
* backup-restic.sh (1.2)
* cpwpcheck.sh (1.1)
* mysqltuner (1.7.24)
* spectre-meltdown-checker (latest)

### Other

* profile.d/z-aeris.sh

## Easy installation for CentOS

There's packages available for CentOS 6, 7 and 8. The easiest way to install it is using Aeris Network yum repository:

```bash
CentOS 6 > yum install -y https://repo.aerisnetwork.com/pub/aeris-release-6.rpm
CentOS 7 > yum install -y https://repo.aerisnetwork.com/pub/aeris-release-7.rpm
CentOS 8 > dnf install -y https://repo.aerisnetwork.com/pub/aeris-release-8.rpm
```

Once the repository is configured, you can proceed with installing nginx-more:

```bash
> yum install aeris-tools
```
