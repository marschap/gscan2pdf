Name:      gscan2pdf
Version: 0.9.28
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
Requires: perl-PerlMagick, ImageMagick, djvulibre, sane-backends
Requires: sane-frontends, xdg-utils, unpaper, gocr, tiff, perl(Gtk2::ImageView)
Requires: perl(Gtk2::Ex::PodViewer), perl(PDF::API2), perl(Config::General)

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
%{_datadir}/pixmaps/gscan2pdf.svg
%{_mandir}/man1/*.1*

%changelog
* Thu Apr 30 2009 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - New upstream release.
    Closes: #506150
     (gscan2pdf: pdf creation failes when using LZW compression)
    Closes: #512758 (Error handling: 'Unknown message: "scanimage: sane_read:
     Operation was cancelled"')
    Closes: #512760 (Error reporting: empty document feeder not reported)
    Closes: #515605 (gscan2pdf: repeating save-dialog when saving as pnm)
    Closes: #517913 (gscan2pdf: Tools -> Gimp broken)
    New Depends: libset-intspan-perl, libforks-perl
  - New upstream release.
    Closes: #500547 (fails to save PDF files)
    Closes: #497629 (Rotation of pages does work on manual double sided
                                                                      scanning)
    Closes: #497630 (Selection of all odd pages or all even pages)
    Closes: #504543 (gscan2pdf: Resolution strangeness)
    Closes: #504546 (gscan2pdf: Resolution not sent to gimp)
    Closes: #507032 (improper window split between page list and preview pane)
    New Depends: libsane-perl
  - New upstream release.
    Closes: #490356 (gscan2pdf: It is impossible to save current session)
    Closes: #486115 (PDF files from gscan2pdf are huge)
    Closes: #493837 (gscan2pdf: should depend on sane-utils, not libsane)
    Closes: #494074 (Select All Text; Save all OCRed text)
    New Depends: libarchive-tar-perl
  - New upstream release.
    Now Depends: libconfig-general-perl (>= 2.40) to avoid heredoc bug
    Closes: #480947 (gscan2pdf: Defaults for pages are weird now)
    Closes: #486553 (gscan2pdf: unable to save as DjVu)
    Closes: #486680 (gscan2pdf: bizarre DjVu text zones)
    Closes: #485641 (gscan2pdf: No longer saves resolution in TIFF files)
    Closes: #484641 (gscan2pdf: prefix option for scanimage command)
  - Bumped Standards-Version
  - New upstream release.
    New Depends: libgtk2-imageview-perl
  - Updated Homepage and Vcs* sections
  - Bumped compat 4->5
  - New upstream release.
    Closes: #463708 (gscan2pdf: Error when saving as PNG)
    Closes: #462171 (importing DjVu files fails, hogs memory)
  - New upstream release.
    Closes: #461859 (better selected/current/all heuristic)
    Closes: #461076 (importing PDFs causes /tmp/ overflow)
  - New upstream release.
    Closes: #449421 (Recognise warm-up message from gt68xx driver)
    Closes: #457377 (Can't save files with spaces in names)
    Closes: #457376 (gscan2pdf: Some paper sizes not available)
    Closes: #457249 (gscan2pdf: Tries to set threshold option for color scans)
    Closes: #457375 (gscan2pdf: Nondeterministic duplex scanning)
    Closes: #461058 (does not ask when quitting without saving the PDF)
  - Updated rules to dh-make-perl 0.35
  - Bumped Standards-Version
  - + watch file
  - New upstream release.
    Closes: #440902 (window placement of scan dialog)
  - New upstream release.
  - New upstream release.  Closes: #433497, #426525, #440204.
  - Thanks to Jeffrey Ratcliffe for contributing to this Debian release.
  - Added Jeffrey Ratcliffe to Uploaders.
  - New upstream release.
  - New upstream release.
  - Initial upload to Debian.  Closes: #420953.
  - Added support for negative ranges on sliders. [516c47fb2f00]
  - Added support for brightness slider.  Needed for Visioneer Strobe XP
    450 scanners.  [516c47fb2f00]
  - Added scanners/xp450 [b68d6a627700]
  - Add .tif extension when saving TIFF and DjVu files, to match PDF
    code.  Fix up PDF saving extension regexp. [a0354eeeb4bf, 06425ce40520]
