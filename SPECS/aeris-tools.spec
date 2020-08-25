%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')

Name:			aeris-tools
Version:		1.8
Release:		3%{?dist}
Summary:		A set of tools and scripts for Web hosting servers

Group:			Utilities/Console
License:		MIT
URL:			https://repo.aerisnetwork.com
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Source0:		https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
Source1:		apache-top.py
Source2:		backup-mysql.sh
Source3:		cpwpcheck.sh
Source4:		archivecheck.sh
Source5:		https://raw.githubusercontent.com/speed47/spectre-meltdown-checker/master/spectre-meltdown-checker.sh
Source6:		backup-restic.sh

Source100:		aeris.sh

BuildRequires:	setup

Requires:		mutt
%if 0%{?rhel} >= 7
Requires:		perl-Getopt-Long
%endif

%description
This package includes a set of tools and scripts for Web hosting servers from different vendor including Aeris Network.

%prep
%setup -q -c -T

%install

install -d -m 0700 %{buildroot}/opt/aeris
install -d -m 0700 %{buildroot}/opt/aeris/tools
install -p -m 0700 %{SOURCE0} %{SOURCE1} %{SOURCE2} %{SOURCE3} %{SOURCE4} %{SOURCE5} %{SOURCE6} %{buildroot}/opt/aeris/tools

install -d -m 0755 %{buildroot}%{_sysconfdir}/profile.d
install -p -m 0644 %{SOURCE100} %{buildroot}%{_sysconfdir}/profile.d/z-aeris.sh

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
%{_sysconfdir}/profile.d/z-aeris.sh


%changelog
* Tue Aug 25 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.8-3
- Add restic wrapper script

* Tue May 12 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.7-3
- Add function to check website SSL validity

* Mon May 11 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.6-3
- Add spectre-meltdown-checker script
- Fetch mysqltuner from GitHub

* Wed Apr 22 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.5-2
- Add custom bash profile with aliases and functions

* Fri Jan 10 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.4-2
- Add CentOS 8 support

* Wed Nov 27 2019 Karl Johnson <karljohnson.it@gmail.com> - 1.4-1
- Add new script to verify tar archive integrity
- Switch license to MIT

* Wed Nov 13 2019 Karl Johnson <karljohnson.it@gmail.com> - 1.3-1
- Bump mysqltuner 1.7.19
- Add ionice to backup-mysql script
- Disable tables locking during the dump with backup-mysql script


* Mon Feb 18 2019 Karl Johnson <karljohnson.it@gmail.com> - 1.2-1
- Fix apache-top view for recent cPanel/Apache
- Bump mysqltuner 1.7.14

* Wed Nov 7 2018 Karl Johnson <karljohnson.it@gmail.com> - 1.1-1
- Add optional number of rentention days in backup-mysql.sh 1.2
- Bump mysqltuner 1.7.13

* Thu Jan 25 2018 Karl Johnson <karljohnson.it@gmail.com> - 1.0-1
- Initial release with mysqltuner 1.7.5, apache-top.py 2006, backup-mysql.sh 1.1, cpwpcheck.sh 1.1
