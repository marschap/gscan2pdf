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
    return $string;
}

sub MY::install {
    my $self = shift;
    my $string = $self->MM::install();
    $string =~ s/doc_install/doc_install locale_install icon_install/;
    return $string;
}

sub MY::preamble {
 my $preamble = <<'END';
PO = $(wildcard po/*.po)
END
 $preamble;
}

sub MY::postamble {
 my $postamble = <<'END';
rpmdist : $(NAME).spec tardist
	$(MKPATH) rpm rpm/SPECS rpm/SOURCES rpm/BUILD rpm/RPMS rpm/SRPMS \
                                                  rpm/RPMS/noarch || /bin/true
	cp $(NAME).spec rpm/SPECS/$(NAME).spec
	cp $(NAME)-$(VERSION).tar.gz \
	                             rpm/SOURCES/$(NAME)-$(VERSION).tar.gz
	( cd rpm/SPECS; \
	  rpmbuild --define='_topdir $(PWD)/rpm' -ba $(NAME).spec )

locale_install : locale
	for file in $(PO); do \
         po=$${file#*/}; \
         umask 02; $(MKPATH) $(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         cp $(LOCALE)/$${po%%.po}/LC_MESSAGES/$(NAME).mo \
                                      $(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         done

icon_install :
	cp $(NAME).desktop $(SHAREDIR)/applications

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
         $(MKPATH) $(LOCALE)/$${po%%.po}/LC_MESSAGES; \
         mv messages.mo $(LOCALE)/$${po%%.po}/LC_MESSAGES/$(NAME).mo; \
         $(MKPATH) tmp$(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         cp $(LOCALE)/$${po%%.po}/LC_MESSAGES/$(NAME).mo \
                                    tmp$(LOCALEDIR)/$${po%%.po}/LC_MESSAGES; \
         done

deb/control : $(NAME)
	cp deb/control deb/control_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < deb/control_tmp > deb/control
	rm deb/control_tmp

htdocs/download/debian/binary/$(NAME)-$(VERSION).deb : tmp/DEBIAN/md5sums
	dpkg-deb -b tmp $(NAME)-$(VERSION).deb
	cp $(NAME)-$(VERSION).deb htdocs/download/debian/binary

tmp/DEBIAN/md5sums : $(NAME) deb/control locale
	$(MKPATH) tmp/DEBIAN tmp$(DIST_BIN) tmp/usr/share/applications
	cp deb/control tmp/DEBIAN
	cp $(NAME) tmp$(DIST_BIN)
	chmod a+rx tmp$(DIST_BIN)/$(NAME)
	cp $(NAME).desktop tmp/usr/share/applications
	cd tmp ; md5sum $(shell find tmp -type f | \
                        awk '/.\// { print substr($$0, 5) }') > DEBIAN/md5sums

htdocs/download/debian/binary/Packages.gz : htdocs/download/debian/binary/$(NAME)-$(VERSION).deb
	cd htdocs/download/debian ; \
         dpkg-scanpackages binary /dev/null | gzip -9c > binary/Packages.gz

remote-dist : htdocs/download/debian/binary/$(NAME)-$(VERSION).deb htdocs/download/debian/binary/Packages.gz
	scp htdocs/download/debian/binary/$(NAME)-$(VERSION).deb \
            htdocs/download/debian/binary/Packages.gz \
	    ra28145@shell.sf.net:/home/groups/g/gs/$(NAME)/htdocs/download/debian/binary

htdocs/index.html : $(NAME)
	pod2html --title=$(NAME)-$(VERSION) $(NAME) > htdocs/index.html

remote-html : htdocs/index.html
	scp htdocs/index.html ra28145@shell.sf.net:/home/groups/g/gs/$(NAME)/htdocs/

po/$(NAME).pot : $(NAME)
	xgettext -L perl --keyword=get -o - $(NAME) | \
         sed 's/SOME DESCRIPTIVE TITLE/messages.pot for $(NAME)/' | \
         sed 's/PACKAGE VERSION/$(NAME)-$(VERSION)/' | \
         sed "s/YEAR THE PACKAGE'S COPYRIGHT HOLDER/$(YEAR) $(AUTHOR)/" | \
         sed 's/PACKAGE/$(NAME)/' | \
         sed 's/FIRST AUTHOR <EMAIL@ADDRESS>, YEAR/$(AUTHOR) <$(EMAIL)>, $(YEAR)/' | \
         sed 's/Report-Msgid-Bugs-To: /Report-Msgid-Bugs-To: $(EMAIL)/' \
         > $@
END
 $postamble;
}
