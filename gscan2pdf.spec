Name:           gscan2pdf
Version:        0.8.3
Release:        1%{?dist}
Summary:        A GUI to ease the process of producing a multipage PDF from a scan

Group:          Applications/Publishing
License:        GPL
URL:            http://gscan2pdf.sourceforge.net/
Source0:        http://easynews.dl.sourceforge.net/sourceforge/gscan2pdf/gscan2pdf-0.7.12.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

ExclusiveArch: noarch

%description
At maturity, the GUI will have similar features to that of the Windows Imaging
program, but with the express objective of writing a PDF, including metadata.

Scanning is handled with SANE via scanimage. PDF conversion is done by libtiff.


%prep
%setup -q

# create .desktop file
cat > %name.desktop <<EOF
[Desktop Entry]
Name=gscan2pdf
Comment=Scan to multipage PDFs
Exec=/usr/bin/gscan2pdf
Type=Application
Terminal=false
Categories=Application;Office;
Encoding=UTF-8
X-Desktop-File-Install-Version=0.9
EOF

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}
make install DESTDIR=$RPM_BUILD_ROOT BIN_DIR=$RPM_BUILD_ROOT%{_bindir}

mkdir -p $RPM_BUILD_ROOT%{_datadir}/applications
cp %{name}.desktop $RPM_BUILD_ROOT%{_datadir}/applications/


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%doc COPYING INSTALL LICENSE 
%{_bindir}/gscan2pdf
%{_datadir}/applications/%{name}.desktop

%changelog
