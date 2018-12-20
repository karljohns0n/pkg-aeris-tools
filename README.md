## Synopsis

This package provides a set of tools and scripts for Web hosting servers from different vendors including Aeris Network.

## Tools

* apache-top.py (2018)
* backup-mysql.sh (1.2)
* cpwpcheck.sh (1.1)
* mysqltuner (1.7.14)

## Easy installation for CentOS

There's a package available for CentOS 6 and 7. The easiest way to install it is to use Aeris Network yum repository.

```bash
CentOS 6 > yum install https://repo.aerisnetwork.com/stable/centos/6/x86_64/aeris-release-1.0-4.el6.noarch.rpm
CentOS 7 > yum install https://repo.aerisnetwork.com/stable/centos/7/x86_64/aeris-release-1.0-4.el7.noarch.rpm
```
Once the repository is configured, you can proceed installing aeris-tools.

```bash
#> yum install aeris-tools
```
