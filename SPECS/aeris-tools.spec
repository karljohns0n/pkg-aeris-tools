%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')

Name:			aeris-tools
Version:		1.1
Release:		1%{?dist}
Summary:		A set of tools and scripts for Web hosting servers

Group:			Utilities/Console
License:		GPLv3+
URL:			https://repo.aerisnetwork.com
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Source0:		mysqltuner.pl
Source1:		apache-top.py
Source2:		backup-mysql.sh
Source3:		cpwpcheck.sh

Requires: mutt

%description
This package includes a set of tools and scripts for Web hosting servers from different vendor including Aeris Network.

%prep
%setup -q -c -T

%install

install -d -m 0700 %{buildroot}/opt/aeris
install -d -m 0700 %{buildroot}/opt/aeris/tools

install -p -m 0700 %{SOURCE0} %{SOURCE1} %{SOURCE2} %{SOURCE3} %{buildroot}/opt/aeris/tools

%clean
if [ -d %{buildroot} ] ; then
	rm -rf %{buildroot}
fi

%post

%files
%defattr(-,root,root,-)
%attr(0700,root,root) /opt/aeris/tools/*
%dir /opt/aeris
%dir /opt/aeris/tools

%changelog
* Wed Nov 7 2018 Karl Johnson <karljohnson.it@gmail.com> - 1.1-1
- Add optional number of rentention days in backup-mysql.sh 1.2
- Bump mysqltuner 1.7.13

* Thu Jan 25 2018 Karl Johnson <karljohnson.it@gmail.com> - 1.0-1
- Initial release with mysqltuner 1.7.5, apache-top.py 2006, backup-mysql.sh 1.1, cpwpcheck.sh 1.1