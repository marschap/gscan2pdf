use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $program = "gscan2pdf";
my $year = (localtime)[5] + 1900;
my $author = "Jeffrey Ratcliffe";
my $email = 'ra28145@users.sourceforge.net';

# Slurp the program source and dig out the version number.
my $text = do { local( @ARGV, $/ ) = "bin/$program" ; <> };
my $version = $1 if ($text =~ /my \$version = '(.*)'/);

my @argv=@ARGV;
my $prefixdir;
my $sharedir;
my $shareinstdir;

@ARGV=();
foreach (@argv) {
    if (m!PREFIX=(.+)!) {
        $prefixdir = $1;
        push @ARGV, $_;
    } elsif (m!SHAREINSTDIR=(.+)!) {
        $shareinstdir = $1;
    } elsif (m!SHAREDIR=(.+)!) {
        $sharedir = $1;
    } else {
        push @ARGV, $_;
    }
}

$prefixdir = "/usr" unless ($prefixdir);
$sharedir = $prefixdir."/share" unless ($sharedir);
$localedir = $sharedir."/locale" unless ($localedir);

WriteMakefile(
              NAME            => $program,
              VERSION         => $version,
              'EXE_FILES'     => [ "bin/$program" ],
              PREREQ_PM       => {
                                   Gtk2                   => 1.08,
                                   Gtk2::Ex::Simple::List => 0,
                                   Image::Magick          => 0,
                                   Locale::gettext        => 1.05,
                                   Config::General        => 0,
              },
              ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
              (ABSTRACT_FROM  => "bin/$program", # retrieve abstract from module
              AUTHOR          => "$author <$email>") : ()),
);

sub MY::macro {
    my $self = shift;
    my $string = $self->MM::macro();
    $string .= "SHAREDIR=$sharedir\n";
    $string .= "LOCALEDIR=$localedir\n";
    $string .= "AUTHOR=$author\n";
    $string .= "EMAIL=$email\n";
    $string .= "YEAR=$year\n";

    $string .= "SITEPREFIX=/usr\n";
    $string .= "INSTALLMAN1DIR=/usr/share/man/man1\n";
    $string .= "INSTALLSITEMAN1DIR=/usr/share/man/man1\n";
    $string .= "INSTALLMAN3DIR=/usr/share/man/man3\n";
    $string .= "INSTALLSITEMAN3DIR=/usr/share/man/man3\n";
    $string .= "MAN1EXT=1p\n";
    return $string;
}

sub MY::install {
    my $self = shift;
    my $string = $self->MM::install();
    $string =~ s/doc_install/doc_install locale_install icon_install/;
    return $string;
}

sub MY::postamble {
 my $postamble = <<'END';
PO = $(wildcard po/*.po)
DEB_BUILD_ROOT = /var/tmp/$(NAME)-$(VERSION)

rpmdist : $(NAME).spec tardist
	mkdir --parents rpm rpm/SPECS rpm/SOURCES rpm/BUILD rpm/RPMS rpm/SRPMS \
                                                  rpm/RPMS/noarch || /bin/true
	cp $(NAME).spec rpm/SPECS/$(NAME).spec
	cp $(NAME)-$(VERSION).tar.gz rpm/SOURCES/$(NAME)-$(VERSION).tar.gz
	( cd rpm/SPECS; \
	  rpmbuild --nodeps --define='_topdir $(PWD)/rpm' -ba $(NAME).spec )

locale_install : locale
	for file in $(PO); do \
         po=$${file#*/}; \
         mkdir --parents $(DESTDIR)$(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         cp $${po%%.po}/LC_MESSAGES/$(NAME).mo \
                              $(DESTDIR)$(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         done

$(DESTDIR)$(SHAREDIR)/$(NAME) :
	mkdir --parents $(DESTDIR)$(SHAREDIR)/$(NAME)

icon_install : $(DESTDIR)$(SHAREDIR)/$(NAME)
	mkdir --parents $(DESTDIR)$(SHAREDIR)/applications
	cp $(NAME).desktop $(DESTDIR)$(SHAREDIR)/applications
	cp $(NAME).png stock-rotate-90.svg stock-rotate-180.svg stock-rotate-270.svg scanner.png pdf.png $(DESTDIR)$(SHAREDIR)/$(NAME)

debdist : htdocs/download/debian/binary/$(NAME)_$(VERSION)_all.deb

html : htdocs/index.html

pot : po/$(NAME).pot

po.tar.gz : po/$(NAME).pot $(PO)
	cd po; tar cfvz po.tar.gz $(NAME).pot *.po
	mv po/po.tar.gz .

locale : $(PO)
	for file in $(PO); do \
         msgfmt -c $$file; \
         po=$${file#*/}; \
         mkdir --parents $${po%%.po}/LC_MESSAGES; \
         mv messages.mo $${po%%.po}/LC_MESSAGES/$(NAME).mo; \
         done

debian/changelog : bin/$(NAME)
	cp debian/changelog debian/changelog_tmp
	sed 's/^$(NAME) (.*)/$(NAME) ($(VERSION))/' < debian/changelog_tmp | \
         sed '/^ --.*/d' > debian/changelog
	rm debian/changelog_tmp
	echo " -- $(AUTHOR) <Jeffrey.Ratcliffe@bigfoot.com>  "`date +'%a, %d %b %Y %H:%M:%S %z'` >> debian/changelog

$(NAME).spec : bin/$(NAME) debian/changelog
	cp $(NAME).spec $(NAME).spec_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < $(NAME).spec_tmp | \
         sed '/^%changelog/q' > $(NAME).spec
	rm $(NAME).spec_tmp
	echo "*" `date +'%a %b %d %Y'` "$(AUTHOR) <$(EMAIL)>" >> $(NAME).spec
	sed 's/^$(NAME).*//' < debian/changelog | \
         sed 's/^ --.*//' | sed 's/^  \*/  -/' | sed '/^$$/d' >> $(NAME).spec

htdocs/download/debian/binary/$(NAME)_$(VERSION)_all.deb : bin/$(NAME) debian/control debian/changelog tardist | htdocs/download/debian/binary
	rm -rf /tmp/$(NAME)
	mkdir /tmp/$(NAME)
	cd /tmp/$(NAME) && tar xvfz $(PWD)/$(NAME)-$(VERSION).tar.gz
	cd /tmp/$(NAME)/$(NAME)-$(VERSION) && perl Makefile.PL \
	 && make locale && debuild && cd .. \
	 && cp $(NAME)_$(VERSION)_all.deb \
	       $(NAME)_$(VERSION).dsc \
	       $(NAME)_$(VERSION)_i386.changes \
	       $(NAME)_$(VERSION).tar.gz $(PWD)/htdocs/download/debian/binary

htdocs/download/debian/binary/Packages.gz : htdocs/download/debian/binary/$(NAME)_$(VERSION)_all.deb | htdocs/download/debian/binary
	cd htdocs/download/debian ; \
	 dpkg-scanpackages binary /dev/null > binary/Packages ; \
	 bzip2 -k binary/Packages ; \
	 gzip -9c binary/Packages > binary/Packages.gz

htdocs/download/debian/binary/Release.gpg : htdocs/download/debian/binary/Release
	gpg --sign -ba -o htdocs/download/debian/binary/Release.gpg htdocs/download/debian/binary/Release

htdocs/download/debian/binary/Release : htdocs/download/debian/binary/Packages.gz
	cd htdocs/download/debian/binary ; \
	 rm Release* ; \
	 apt-ftparchive release . \
          -o APT::FTPArchive::Release::Origin="Jeffrey Ratcliffe" \
          -o APT::FTPArchive::Release::Label="Jeff's gscan2pdf repository" \
          -o APT::FTPArchive::Release::Codename="binary" \
          -o APT::FTPArchive::Release::Architectures="noarch" \
          -o APT::FTPArchive::Release::Components="gscan2pdf" \
          -o APT::FTPArchive::Release::Description="gscan2pdf Debian packages" \
	  > Release.tmp ; \
	 mv Release.tmp Release

htdocs/download/debian/binary :
	mkdir --parents htdocs/download/debian/binary

remote-dist : htdocs/download/debian/binary/$(NAME)_$(VERSION)_all.deb htdocs/download/debian/binary/Release.gpg
	scp htdocs/download/debian/binary/$(NAME)_$(VERSION)_all.deb \
            htdocs/download/debian/binary/$(NAME)_$(VERSION).dsc \
            htdocs/download/debian/binary/$(NAME)_$(VERSION)_i386.changes \
	    htdocs/download/debian/binary/$(NAME)_$(VERSION).tar.gz \
            htdocs/download/debian/binary/Packages \
            htdocs/download/debian/binary/Packages.gz \
	    htdocs/download/debian/binary/Release \
	    htdocs/download/debian/binary/Release.gpg \
	    ra28145@shell.sf.net:/home/groups/g/gs/$(NAME)/htdocs/download/debian/binary

htdocs/index.html : bin/$(NAME)
	if [ ! -d htdocs ] ; then mkdir htdocs ; fi
	pod2html --noindex --title=$(NAME)-$(VERSION) bin/$(NAME) > htdocs/index.html

remote-html : htdocs/index.html
	scp htdocs/index.html ra28145@shell.sf.net:/home/groups/g/gs/$(NAME)/htdocs/

po/$(NAME).pot : bin/$(NAME)
	xgettext -L perl --keyword=get --from-code=UTF-8 -o - bin/$(NAME) | \
         sed 's/SOME DESCRIPTIVE TITLE/messages.pot for $(NAME)/' | \
         sed 's/PACKAGE VERSION/$(NAME)-$(VERSION)/' | \
         sed "s/YEAR THE PACKAGE'S COPYRIGHT HOLDER/$(YEAR) $(AUTHOR)/" | \
         sed 's/PACKAGE/$(NAME)/' | \
         sed 's/FIRST AUTHOR <EMAIL@ADDRESS>, YEAR/$(AUTHOR) <$(EMAIL)>, $(YEAR)/' | \
         sed 's/Report-Msgid-Bugs-To: /Report-Msgid-Bugs-To: $(EMAIL)/' | \
         grep -v fuzzy > $@
END
 $postamble;
}
