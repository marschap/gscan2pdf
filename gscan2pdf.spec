Name:      gscan2pdf
Version: 0.8.4
Release:   1%{?dist}
Summary:   A GUI to ease the process of producing a multipage PDF from a scan
Group:     Applications/Publishing
License:   GPL
URL:       http://%{name}.sourceforge.net/
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
Packager:  Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
Requires:  perl(Gtk2) >= 1:1.043-1, perl(Glib) >= 1.100-1, perl(Locale::gettext) >= 1.05, sane, libtiff

%description
At maturity, the GUI will have similar features to that of the Windows Imaging
program, but with the express objective of writing a PDF, including metadata.

Scanning is handled with SANE via scanimage. PDF conversion is done by libtiff.

%prep
%setup -q

%build
rm -rf $RPM_BUILD_ROOT
perl Makefile.PL
make
make test

%install
make DESTDIR=$RPM_BUILD_ROOT INSTALLMAN1DIR=/usr/share/man/man1 \
     INSTALLSITEMAN1DIR=/usr/share/man/man1 INSTALLMAN3DIR=/usr/share/man/man3 \
     INSTALLSITEMAN3DIR=/usr/share/man/man3 SITEPREFIX=/usr MAN1EXT=1p install
find $RPM_BUILD_ROOT -name perllocal.pod | xargs rm -f
find $RPM_BUILD_ROOT -name .packlist | xargs rm -f

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc COPYING INSTALL LICENCE History
%{_bindir}/gscan2pdf
%{_datadir}/applications/%{name}.desktop
%{_datadir}/locale/de/LC_MESSAGES/%{name}.mo
%{_datadir}/locale/en_GB/LC_MESSAGES/%{name}.mo
%{_datadir}/locale/fr/LC_MESSAGES/%{name}.mo
%{_datadir}/locale/nl/LC_MESSAGES/%{name}.mo
%{_datadir}/locale/pl/LC_MESSAGES/%{name}.mo
%{_datadir}/locale/sv/LC_MESSAGES/%{name}.mo
%{_mandir}/man1/gscan2pdf.1p.gz

%changelog
