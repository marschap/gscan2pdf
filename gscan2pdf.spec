Name:      gscan2pdf
Version: 0.9.15
Release:   1%{?dist}
Summary:   A GUI to produce PDFs from scanned documents

Group:     Applications/Publishing
License:   GPL
URL:       http://%{name}.sourceforge.net/
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch

BuildRequires: perl(ExtUtils::MakeMaker), perl(Test::More)
BuildRequires: gettext, desktop-file-utils
Requires: perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires: ImageMagick-perl, ImageMagick, djvulibre, sane-backends
Requires: sane-frontends, xdg-utils, unpaper, gocr
Requires: perl(Gtk2::Ex::PodViewer), perl(PDF::API2)

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
%{perl_vendorlib}/Gscan2pdf.pm
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_mandir}/man1/*.1*

%changelog
* Sun Jul 22 2007 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - Fixed bug setting defaults, also responsible for preventing the
    device-dependent options being displayed in certain circumstances.
  - store unpaper options in settings
  - fractional instead of pulsing ProgressBar & more info during PDF save
  - fixed bug where spaces in mode not escaped in shell
  - fixed bug parsing device-dependent options (affecting some Brother scanners).
  - option not to restore window settings.
    closes Debian bug 433497 (please don't remember window position)
  - Update to French translation (thanks to Nicolas Stransky)
