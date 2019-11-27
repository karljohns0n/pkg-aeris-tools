# Aeris Tools

[![ProjectStatus](http://opensource.box.com/badges/active.svg)](#)
[![Release 1.4-1](https://img.shields.io/badge/release-1.4--1-success.svg)](#)
[![Change Log](https://img.shields.io/badge/change-log-blue.svg?style=flat)](https://repo.aerisnetwork.com/stable/centos/6/x86_64/repoview/aeris-tools.html)

## Synopsis

This package provides a set of tools and scripts for Web hosting servers from different vendors including Aeris Network.

## Tools

* apache-top.py (2018)
* archivecheck.sh (1.1)
* backup-mysql.sh (1.3)
* cpwpcheck.sh (1.1)
* mysqltuner (1.7.19)

## Easy installation for CentOS

There's a package available for CentOS 6 and 7. The easiest way to install it is to use Aeris Network yum repository.

```bash
CentOS 6 > yum install https://repo.aerisnetwork.com/pub/aeris-release-6.rpm
CentOS 7 > yum install https://repo.aerisnetwork.com/pub/aeris-release-7.rpm
```
Once the repository is configured, you can proceed installing aeris-tools.

```bash
#> yum install aeris-tools
```