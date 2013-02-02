Name:      gscan2pdf
Version: 1.1.1
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
export DISPLAY=:0.0
#make test

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
%{perl_vendorlib}/*
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/pixmaps/gscan2pdf.svg
%{_mandir}/man1/*.1*

%changelog
* Sat Feb 02 2013 Jeffrey Ratcliffe <ra28145@users.sourceforge.net>
  - New upstream release
  - New upstream release
    Closes: #682818 (Presets aren't working)
  - Added depends: libtry-tiny-perl
  - New upstream release
  - New upstream release
    Closes: #670640 (Can't call method get_cmdline)
  - Recommend tesseract OR gocr OR cuneiform, rather than AND
    Closes: #682100 gscan2pdf Recommends cuneiform which is in non-free
  - Fix updating widgets in scanimage dialog
    Closes: #678911
    (Device-dependent options disappear after selecting Lineart mode)
  - Fixed warning in lib/Gscan2pdf/Scanner/Options.pm
  - Fix unpaper as part of scan process
    Closes: #670640 (Can't call method get_cmdline)
  - Deal with non-utf-8 characters in OCR output
    Closes: #670831 (not resilient against non utf-8 from tesseract)
  - Bumped standards to 3.9.3 (no changes required)
  - New upstream release
  - New upstream release
  - Updated Depends on libsane-perl to 0.05
  - New upstream release
    Closes: #663584 (copy-paste of pages corrupts document)
    Closes: #664635 (Fails to restore session, invalid pathname)
    Closes: #665871 (no longer offers 'tesseract' OCR, persistently)
  - New upstream release
    Closes: #653918 (gscan2pdf doesn't save metadata anymore)
    Closes: #646298 (pdf-exports of ocropus texts are slow, big)
    Closes: #646246 (gscan2pdf ignores html-entities returned by ocropus
                     documents)
    Closes: #651666 (ability to preview saved files)
    Closes: #645322 (No lock after recovery can result in data loss)
    Closes: #645323 (Imported pages have no thumbnails)
  - Bumped standards to 3.9.2 (no changes required)
  - New upstream release
    Closes: #622616 (gscan2pdf: error message)
    Closes: #622844 (gscan2pdf + libsane-perl frontend + Canon CanoScan LiDE25
                     results in "End of file reached")
    Closes: #563461 (ability to remove unreferenced temporary files)
    Closes: #577144 (gscan2pdf: lost option for editing/scanning simultaneously
                     in newer versions)
    Closes: #602578 (Clearing the OCR text)
    Closes: #617886 ("Open gscan2pdf session file" icon looks too much like
                     "Save" icon)
  - New upstream release
    Closes: #599181 (gscan2pdf: OCR doesn't support Umlauts/national characters)
    Closes: #608226 (pressing space causes unexpected data loss)
    New Depends: liblog-log4perl-perl
    Removed Depends: libarchive-tar-perl, as now in perl
  - Removed debian/patches/replace-forks-with-threads
    Removed Build-Depends: quilt
    Updated rules not to use quilt
  - Replace forks with threads
    Closes: #591404 (gscan2pdf: libforks-perl could be removed)
    Removed Depends: libforks-perl
    Added Build-Depends: quilt
    Updated rules to use quilt
  - Bumped standards to 3.9.1 (no changes required)
  - New upstream release
    Closes: #510309 (gscan2pdf: Ability to configure how GIMP is started)
    Closes: #576193 (gscan2pdf: OCR does not works, due to Goo::Canvas::Text
                                                            programming error)
    Closes: #584787 (gscan2pdf: Gscan2pdf quits without saving)
    Closes: #585441 (gscan2pdf: "Useless use of sort in void context")
    New Depends: libhtml-parser-perl, libreadonly-perl
    Removed Depends: libxml-simple-perl
    New Recommends: cuneiform
  - Minor editing of description
  - Patched the clean target to fix FTBFS
  - Bumped standards to 3.9.0 (no changes required)
  - New upstream release.
    Closes: #461086 (embed OCR output at correct position)
    Closes: #510314 (gscan2pdf: Mapping File_Scan to a shortcut key)
    Closes: #557657 (gscan2pdf binarization option [wishlist])
    New Depends: libxml-simple-perl, libgoo-canvas-perl,
	         libproc-processtable-perl
  - Removed URL from description
    Closes: #564325 (gscan2pdf: please remove homepage from description)
  - Fixed VCS-URLs
  - Bumped standards to 3.8.3 (no changes required)
  - Switch to tiny dh7 rules
  - Added ${misc:Depends}
  - New upstream release.
    Closes: #526845
     (gscan2pdf: Renaming of frontends breaks current settings)
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
