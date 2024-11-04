%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')

Name:			aeris-tools
Version:		1.19
Release:		1%{?dist}
Summary:		A set of tools and scripts for Web hosting servers

Group:			Utilities/Console
License:		MIT
URL:			https://repo.aerisnetwork.com
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Source0:		https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
Source1:		backup-mysql.sh
Source2:		cpwpcheck.sh
Source3:		archivecheck.sh
Source4:		https://raw.githubusercontent.com/speed47/spectre-meltdown-checker/master/spectre-meltdown-checker.sh
Source5:		backup-restic.sh
Source6:		https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh
Source7:		https://github.com/gordalina/cachetool/releases/latest/download/cachetool.phar

Source100:		aeris.sh

Source200:		apache-top.py
Source201:		apache-top2.py

BuildRequires:	setup
Requires:		mutt

%if 0%{?rhel} >= 7
Requires:		perl-Getopt-Long
%endif

%if 0%{?rhel} <= 8
Requires:		mailx
%endif

%if 0%{?rhel} == 9
Requires:		s-nail perl-diagnostics
%endif

%description
This package includes a set of tools and scripts for Web hosting servers from different vendor including Aeris Network.

%prep
%setup -q -c -T

%install

install -d -m 0755 %{buildroot}/opt/aeris
install -d -m 0755 %{buildroot}/opt/aeris/tools

%if 0%{?rhel} <= 8
install -p -m 0700 %{SOURCE0} %{SOURCE1} %{SOURCE2} %{SOURCE3} %{SOURCE4} %{SOURCE5} %{SOURCE6} %{SOURCE7} %{SOURCE200} %{SOURCE201} %{buildroot}/opt/aeris/tools
%endif

%if 0%{?rhel} == 9
install -p -m 0700 %{SOURCE0} %{SOURCE1} %{SOURCE2} %{SOURCE3} %{SOURCE4} %{SOURCE5} %{SOURCE6} %{SOURCE7} %{buildroot}/opt/aeris/tools
%endif

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
%attr(0755,root,root) /opt/aeris/tools/cachetool.phar
%attr(0755,root,root) /opt/aeris/tools/yabs.sh
%dir /opt/aeris
%dir /opt/aeris/tools
%{_sysconfdir}/profile.d/z-aeris.sh


%changelog
* Tue Nov 5 2024 Karl Johnson <karljohnson.it@gmail.com> - 1.19-1
- Enhance restic backup with S3 compliant support

* Sat Apr 27 2024 Karl Johnson <karljohnson.it@gmail.com> - 1.18-1
- Remove python2 scripts on el9

* Tue Apr 23 2024 Karl Johnson <karljohnson.it@gmail.com> - 1.17-1
- Add cachetool script
- Bump YABS script to latest

* Sat Apr 6 2024 Karl Johnson <karljohnson.it@gmail.com> - 1.16-1
- Bump mysqltuner.pl to 2.5.3
- Bump spectre-meltdown-checker to latest
- Bump YABS script to latest

* Sat Dec 23 2023 Karl Johnson <karljohnson.it@gmail.com> - 1.15-1
- Bump mysqltuner.pl to 2.5.0
- Bump spectre-meltdown-checker to latest
- Bump YABS script to latest
- Enhance backup-mysql script

* Tue Aug 22 2023 Karl Johnson <karljohnson.it@gmail.com> - 1.14-1
- Bump mysqltuner.pl to 2.2.8
- Bump spectre-meltdown-checker to latest including Downfall
- Add YABS script
- Increase restic backup retention of +1 month

* Fri Jul 15 2022 Karl Johnson <karljohnson.it@gmail.com> - 1.13-1
- Add support for el9
- Bump mysqltuner.pl to 2.0.5

* Mon Mar 28 2022 Karl Johnson <karljohnson.it@gmail.com> - 1.12-5
- Bump mysqltuner.pl to 1.9.6
- Add new apache-top.py compatible with MPM Event
- Fix phpfpmadd for Remi PHP
- Add GoAccess functions

* Sat Nov 13 2021 Karl Johnson <karljohnson.it@gmail.com> - 1.11-5
- Fix phpfpmadd for PHP 7.4
- Bump mysqltuner.pl to 1.8.5
- Bump spectre-meltdown-checker to latest

* Wed Apr 7 2021 Karl Johnson <karljohnson.it@gmail.com> - 1.10-5
- Force mysqldump in case a view isn't valid
- Bump mysqltuner.pl to 1.7.24
- Bump spectre-meltdown-checker to latest

* Sat Nov 7 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.9-5
- Restic wrapper now supports Backblaze B2
- Bump mysqltuner.pl to 1.7.20

* Fri Sep 18 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.8-5
- Require mailx

* Mon Aug 31 2020 Karl Johnson <karljohnson.it@gmail.com> - 1.8-4
- Change restic snapshots retention

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
