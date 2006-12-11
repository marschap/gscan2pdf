use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $program = "gscan2pdf";
my $year = (localtime)[5] + 1900;
my $author = "Jeffrey Ratcliffe";
my $email = 'ra28145@users.sourceforge.net';

# Slurp the gscan2pdf source and dig out the version number.
my $text = do { local( @ARGV, $/ ) = "bin/$program" ; <> };
my $version = $1 if ($text =~ /my \$version = "(.*)"/);

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
              PREREQ_PM       => {Gtk2 => 1.08}, # e.g., Module::Name => 1.1
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
	cp $(NAME)-$(VERSION).tar.gz \
	                             rpm/SOURCES/$(NAME)-$(VERSION).tar.gz
	( cd rpm/SPECS; \
	  rpmbuild --define='_topdir $(PWD)/rpm' -ba $(NAME).spec )

locale_install : locale
	for file in $(PO); do \
         po=$${file#*/}; \
         mkdir --parents $(DESTDIR)$(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         cp $${po%%.po}/LC_MESSAGES/$(NAME).mo \
                              $(DESTDIR)$(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         done

icon_install :
	mkdir --parents $(DESTDIR)$(SHAREDIR)/applications
	cp $(NAME).desktop $(DESTDIR)$(SHAREDIR)/applications

debdist : htdocs/download/debian/binary/$(NAME)-$(VERSION).deb

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

deb/control : bin/$(NAME)
	cp deb/control deb/control_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < deb/control_tmp > deb/control
	rm deb/control_tmp

deb/changelog : bin/$(NAME)
	cp deb/changelog deb/changelog_tmp
	sed 's/^$(NAME) (.*)/$(NAME) ($(VERSION))/' < deb/changelog_tmp > deb/changelog
	rm deb/changelog_tmp

$(NAME).spec : bin/$(NAME) deb/changelog
	cp $(NAME).spec $(NAME).spec_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < $(NAME).spec_tmp | \
         sed '/^%changelog/q' > $(NAME).spec
	rm $(NAME).spec_tmp
	echo "*" `date +'%a %b %d %Y'` "$(AUTHOR) <$(EMAIL)>" >> $(NAME).spec
	sed 's/^$(NAME) (.*)//' < deb/changelog | \
         sed 's/^ --.*//' | sed 's/^  \*/  -/' | sed '/^$$/d' >> $(NAME).spec

htdocs/download/debian/binary/$(NAME)-$(VERSION).deb : $(DEB_BUILD_ROOT)/DEBIAN/md5sums
	dpkg-deb -b $(DEB_BUILD_ROOT) $(NAME)-$(VERSION).deb
	cp $(NAME)-$(VERSION).deb htdocs/download/debian/binary
	rm -rf $(DEB_BUILD_ROOT)

$(DEB_BUILD_ROOT)/DEBIAN/md5sums_files : bin/$(NAME) deb/control locale
	make DESTDIR=$(DEB_BUILD_ROOT) install
	find $(DEB_BUILD_ROOT) -name perllocal.pod | xargs rm -f
	find $(DEB_BUILD_ROOT) -name .packlist | xargs rm -f
	mkdir --parents $(DEB_BUILD_ROOT)/DEBIAN
	cp deb/control deb/debian-binary $(DEB_BUILD_ROOT)/DEBIAN
	find $(DEB_BUILD_ROOT) -type f | \
         awk 'BEGIN {x=length("$(DEB_BUILD_ROOT)")+2} /.\// { print substr($$0, x) }' > $(DEB_BUILD_ROOT)/DEBIAN/md5sums_files

# Have to do this in two stages because $(shell find....) would be carried out before install otherwise
$(DEB_BUILD_ROOT)/DEBIAN/md5sums : $(DEB_BUILD_ROOT)/DEBIAN/md5sums_files
	cd $(DEB_BUILD_ROOT); \
         md5sum $(shell cat $(DEB_BUILD_ROOT)/DEBIAN/md5sums_files) > $(DEB_BUILD_ROOT)/DEBIAN/md5sums

htdocs/download/debian/binary/Packages.gz : htdocs/download/debian/binary/$(NAME)-$(VERSION).deb
	cd htdocs/download/debian ; \
         dpkg-scanpackages binary /dev/null | gzip -9c > binary/Packages.gz

remote-dist : htdocs/download/debian/binary/$(NAME)-$(VERSION).deb htdocs/download/debian/binary/Packages.gz
	scp htdocs/download/debian/binary/$(NAME)-$(VERSION).deb \
            htdocs/download/debian/binary/Packages.gz \
	    ra28145@shell.sf.net:/home/groups/g/gs/$(NAME)/htdocs/download/debian/binary

htdocs/index.html : bin/$(NAME)
	if [ ! -d htdocs ] ; then mkdir htdocs ; fi
	pod2html --title=$(NAME)-$(VERSION) bin/$(NAME) > htdocs/index.html

remote-html : htdocs/index.html
	scp htdocs/index.html ra28145@shell.sf.net:/home/groups/g/gs/$(NAME)/htdocs/

po/$(NAME).pot : bin/$(NAME)
	xgettext -L perl --keyword=get -o - bin/$(NAME) | \
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
