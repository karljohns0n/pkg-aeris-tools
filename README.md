# Aeris Tools

[![ProjectStatus](https://img.shields.io/badge/status-active-brightgreen.svg)](#)
[![Release](https://img.shields.io/badge/release-1.21--1-success.svg)](#)

## Synopsis

This package provides a set of tools and scripts for Web hosting servers based on RHEL.

## Tools

### Scripts

* apache-top.py
* apache-top2.py
* archivecheck.sh
* backup-mysql.sh
* backup-restic.sh
* cachetool.phar
* cpwpcheck.sh
* mysqltuner
* spectre-meltdown-checker

### Other

* profile.d/z-aeris.sh

## Setup

There's packages available for EL 6, 7, 8 and 9. The easiest way to install it is using Aeris Network yum repository:

```bash
EL6 > yum install -y https://repo.aerisnetwork.com/pub/aeris-release-6.rpm
EL7 > yum install -y https://repo.aerisnetwork.com/pub/aeris-release-7.rpm
EL8 > dnf install -y https://repo.aerisnetwork.com/pub/aeris-release-8.rpm
EL9 > dnf install -y https://repo.aerisnetwork.com/pub/aeris-release-9.rpm
EL10 > dnf install -y https://repo.aerisnetwork.com/pub/aeris-release-10.rpm
```

Once the repository is configured, you can proceed with installing nginx-more:

```bash
> yum install aeris-tools
```
