Name:      gscan2pdf
Version: 0.9.13
Release:   1%{?dist}
Summary:   A GUI to produce PDFs from scanned documents

Group:     Applications/Publishing
License:   GPL
URL:       http://%{name}.sourceforge.net/
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch

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

desktop-file-install --delete-original  --vendor="" \
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
* Thu Jul 05 2007 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - Select all or Ctrl-A works properly in thumbnails or OCR buffer, depending on
    focus. Closes bug 1740131 (Ctrl-A (select all) in OCR window does not work).
  - Tesseract support. Closes feature request 1725818 (tesseract for OCR?)
  - unset mode if changing device.
    Closes bug 1741598 (2 scanners with differing mode options).
  - ghost scan all pages RadioButton if Flatbed selected.
    Closes bug 1743059 (Endless scanning loop)
  - trap device busy error. Closes bug 1744451 (handle busy device)
  - Modify PDF metadata date format to conform to ISO-8601
    Closes feature request 1744458 (change dates to ISO-8601)
  - Fixed double scan bug with scanadf frontend
  - Fixed bug where Custom paper size not set from default
  - Update to Danish translation (thanks to Jacob Nielsen)
  - Update to French translation (thanks to Pierre Slamich)
  - Update to Polish translation (thanks to Piotr Strebski)
  - Fixed blocking whilst setting up/updating scan dialog
