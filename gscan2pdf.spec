Name:      gscan2pdf
Version: 0.9.10
Release:   1%{?dist}
Summary:   A GUI to produce PDFs from scanned documents

Group:     Applications/Publishing
License:   GPL
URL:       http://%{name}.sourceforge.net/
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
ExclusiveArch: noarch

BuildRequires:  perl(ExtUtils::MakeMaker), gettext, desktop-file-utils
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:  ImageMagick-perl, djvulibre, sane-backends, sane-frontends, xdg-utils
Requires:  perl(Gtk2::Ex::PodViewer), perl(PDF::API2), unpaper, gocr

Packager:  Jeffrey Ratcliffe <ra28145@users.sourceforge.net>

%description
Only two clicks are required to scan several pages and then save all or a
selection as a PDF file, including metadata if required.

gscan2pdf can control regular or sheet-fed (ADF) scanners with SANE via
scanimage or scanadf, and can scan multiple pages at once. It presents a
thumbnail view of scanned pages, and permits simple operations such as rotating
and deleting pages. 

PDF conversion is done by PDF::API2.

The resulting document may be saved as a PDF or a multipage TIFF file.

%prep
%setup -q

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} ';'
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null ';'
rm -f $RPM_BUILD_ROOT/%{perl_archlib}/perllocal.pod
chmod -R u+w $RPM_BUILD_ROOT/*

desktop-file-install --delete-original \
  --dir=$RPM_BUILD_ROOT/%{_datadir}/applications         \
  $RPM_BUILD_ROOT/%{_datadir}/applications/%{name}.desktop

%find_lang %{name}

%check
make test

%clean
rm -rf $RPM_BUILD_ROOT

%post
update-desktop-database &> /dev/null ||:
touch --no-create %{_datadir}/icons/hicolor || :
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
  %{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :
fi

%postun
update-desktop-database &> /dev/null ||:
touch --no-create %{_datadir}/icons/hicolor || :
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
  %{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :
fi

%files -f %{name}.lang
%defattr(-,root,root,-)
%doc LICENCE
%{_bindir}/*
%{_datadir}/%{name}
%{_datadir}/applications/*-%{name}.desktop
%{_mandir}/man1/*.1*

%changelog
* Mon Jun 04 2007 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - patch credits
  - Switched rotate icons from Crystal (KDE) to those stolen from Eye of Gnome
  - Closed bug 1712967
     (long lines in ocr output resized document display off screen)
  - contrast and threshold controls
  - handle PNG, JPEG, GIF, PNM natively,
     closing feature request 1708448 (JPG to PDF)
     and bugs 1714874 (import b/w pdf problem)
     and 1669413 (Problem with "callback")
  - PDF compression options (JPEG, PNG), closing feature request 1708036
  - --speed option (Epson 1200)
  - ProgressBar for PDF save, closing feature request 1712964
  - Portuguese translation (thanks to Hugo Pereira)
  - Danish translation (thanks to Jacob Nielsen)
  - Update to Czech translation (thanks to Petr Jelínek)
  - Update to Dutch translation (thanks to Eric Spierings)
  - Update to French translation (thanks to codL)
  - remembers OCR on scan setting
  - unpaper on scan
  - calibration-cache option for Canon LiDE25
  - roadmap to website/help
