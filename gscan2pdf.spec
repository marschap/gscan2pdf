Name:      gscan2pdf
Version: 0.9.11
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
%{_datadir}/%{name}/stock-rotate-90.svg
%{_datadir}/%{name}/stock-rotate-180.svg
%{_datadir}/%{name}/stock-rotate-270.svg
%{_datadir}/%{name}/scanner.png
%{_datadir}/%{name}/pdf.png
%{_mandir}/man1/%{name}.1p.gz

%changelog
* Tue Jun 19 2007 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - no-grayfilter option
  - check for mode-dependent options.
  - note resolution info so that the resulting PDF has the correct paper size.
    Closes bug 1736036 (page size is somehow a ratio of resolution)
    and Debian bug 426525 (after unpaper, saving PDF causes magnified page)
  - quality setting for JPG compression in save as PDF.
    Closes feature request 1736043 (Compression setting)
    and bug 1736582 (PDFs with embedded JPEGS are large)
  - save image functionality supporting TIFF, PNG, JPEG, PNM & GIF.
    Closes feature request 1709380 (Support PNG output equivalent to TIFF)
  - save default dates as offset from current, closing bug 1736037
    (pdf file->save dialog should automatically set the date to the current day)
