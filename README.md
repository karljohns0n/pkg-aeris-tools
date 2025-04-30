# Aeris Tools

[![ProjectStatus](https://img.shields.io/badge/status-active-brightgreen.svg)](#)
[![Release](https://img.shields.io/badge/release-1.20--1-success.svg)](#)

## Synopsis

This package provides a set of tools and scripts for Web hosting servers from different vendors including Aeris Network.

## Tools

### Scripts

* apache-top.py (2018)
* apache-top2.py (2020)
* archivecheck.sh (1.1)
* backup-mysql.sh (1.6.0)
* backup-restic.sh (1.3.0)
* cachetool.phar (latest)
* cpwpcheck.sh (1.1)
* mysqltuner (latest)
* spectre-meltdown-checker (latest)

### Other

* profile.d/z-aeris.sh

## Easy installation for CentOS

There's packages available for EL 6, 7, 8 and 9. The easiest way to install it is using Aeris Network yum repository:

```bash
EL6 > yum install -y https://repo.aerisnetwork.com/pub/aeris-release-6.rpm
EL7 > yum install -y https://repo.aerisnetwork.com/pub/aeris-release-7.rpm
EL8 > dnf install -y https://repo.aerisnetwork.com/pub/aeris-release-8.rpm
EL9 > dnf install -y https://repo.aerisnetwork.com/pub/aeris-release-9.rpm
```

Once the repository is configured, you can proceed with installing nginx-more:

```bash
> yum install aeris-tools
```
