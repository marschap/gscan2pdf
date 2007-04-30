Name:      gscan2pdf
Version: 0.9.9
Release:   1%{?dist}
Summary:   A GUI to ease the process of producing a multipage PDF from a scan
Group:     Applications/Publishing
License:   GPL
URL:       http://%{name}.sourceforge.net/
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
ExclusiveArch: noarch
Packager:  Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
Requires:  perl(Gtk2) >= 1:1.043-1, perl(Glib) >= 1.100-1, perl(Locale::gettext) >= 1.05, perl(PDF::API2), perlmagick, sane, libtiff

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
     INSTALLSITEMAN3DIR=/usr/share/man/man3 SHAREINSTDIR=/usr/share/%{name} \
     install
find $RPM_BUILD_ROOT -name perllocal.pod | xargs rm -f
find $RPM_BUILD_ROOT -name .packlist | xargs rm -f

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0644,root,root,0755)
%doc COPYING INSTALL LICENCE History
%attr(0755,root,root) %{_bindir}/gscan2pdf
%{_datadir}/applications/%{name}.desktop
%{_datadir}/locale/*/LC_MESSAGES/%{name}.mo
%{_datadir}/%{name}/%{name}.png
%{_datadir}/%{name}/rotate90.png
%{_datadir}/%{name}/rotate180.png
%{_datadir}/%{name}/rotate270.png
%{_datadir}/%{name}/scanner.png
%{_datadir}/%{name}/pdf.png
%{_mandir}/man1/%{name}.1p.gz

%changelog
* Mon Apr 30 2007 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - Fixed bug calling help
  - Fixed Fixed bug 1709377
     ("Unknwn msg: scanimage: unrec'd option --compression=None'")
  - Fixed bug where attempt to run gocr after scanning despite not being installed
  - Replaced about MessageDialog with AboutDialog
  - Update to Russian translation (thanks to Alexandre Prokoudine)
  - Update to Czech translation (thanks to Petr Jelínek)
  - Update to Dutch translation (thanks to Eric Spierings)
  - Packed unpaper options into Gtk2::Notebook to make dialog shorter, fixed bug
     1709379 ("unpaper-0.2 dialog too tall for 1024x768")
