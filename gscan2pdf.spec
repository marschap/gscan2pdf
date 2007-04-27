Name:      gscan2pdf
Version: 0.9.8
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
* Fri Apr 27 2007 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - Fixed bug calling help
  - - compression option from scan dialog.
  - Explicitly sets compression=None if mode=Lineart
  - Check for PDF::API2
  - Forces startup check on new version
  - Runs unpaper sequencially on pages instead of in parallel
  - Enabled double sided scanning for scanadf frontend
  - no-deskew, no-border-scan, no-border-align, no-mask-scan, no-blackfilter
    no-noisefilter, no-blurfilter, black-threshold, white-threshold options to
    unpaper
  - Stock icon for about
  - Scrolls thumb list to selected page
  - Embeds OCR output in white on white hidden behind scan. pdftotext can extract
    contents, and can be indexed by Beagle.
  - Update to Spanish translation (thanks to Th3n3k)
  - Moved OCR buffer to main window
  - Patch from John Goerzen to adjust brightness
    and add negative support for SpinBoxes
  - Patches from John Goerzen to add .tif and .djvu endings if necessary,
    plus fixed bug adding .pdf ending.
  - Separated perlmagick and imagemagick dependencies
  - Updated French translation (thanks to Mathieu Goeminne)
