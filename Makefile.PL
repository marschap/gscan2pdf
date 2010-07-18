use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $program = "gscan2pdf";
my $year = (localtime)[5] + 1900;
my $author = "Jeffrey Ratcliffe";
my $email = 'ra28145@users.sourceforge.net';

# Slurp the program source and dig out the version number.
my $text = do { local( @ARGV, $/ ) = "bin/$program" ; <> };
my $version = $1 if ($text =~ /my \$version\s*=\s*'(.*)'/);

my @argv=@ARGV;
my $prefixdir;
my $sharedir;
my $shareinstdir;

@ARGV=();
foreach (@argv) {
    if (m!PREFIX=(.+)!i) {
        $prefixdir = $1;
        push @ARGV, $_;
    } elsif (m!SHAREINSTDIR=(.+)!i) {
        $shareinstdir = $1;
    } elsif (m!SHAREDIR=(.+)!i) {
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
              EXE_FILES       => [ "bin/$program",
                                   'bin/scanimage-perl', 'bin/scanadf-perl' ],
              PREREQ_PM       => {
                                   Gtk2                   => 1.090,
                                   Sane                   => 0.02,
                                   Gtk2::Ex::Simple::List => 0,
                                   Gtk2::ImageView        => 0,
                                   Image::Magick          => 0,
                                   Locale::gettext        => 1.05,
                                   Config::General        => 2.40,
                                   PDF::API2              => 0,
                                   Set::IntSpan           => 1.10,
                                   forks                  => 0.33,
                                   XML::Simple            => 0,
                                   Goo::Canvas            => 0,
                                   Readonly               => 0,
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

    $string .= "SITEPREFIX=$prefixdir\n";
    $string .= "INSTALLMAN1DIR=$sharedir/man/man1\n";
    $string .= "INSTALLSITEMAN1DIR=$sharedir/man/man1\n";
    $string .= "INSTALLMAN3DIR=$sharedir/man/man3\n";
    $string .= "INSTALLSITEMAN3DIR=$sharedir/man/man3\n";
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

rpmdist : $(NAME).spec $(NAME).Suse.spec tardist
	$(MKPATH) rpm rpm/SPECS rpm/SOURCES rpm/BUILD rpm/RPMS rpm/SRPMS \
                                                  rpm/RPMS/noarch || /bin/true
	$(CP) $(NAME).spec $(NAME).Suse.spec rpm/SPECS/
	$(CP) $(NAME)-$(VERSION).tar.gz rpm/SOURCES/$(NAME)-$(VERSION).tar.gz
	( cd rpm/SPECS; \
	  rpmbuild --nodeps --define='_topdir $(PWD)/rpm' -ba $(NAME).spec; \
	  rpmbuild --nodeps --define='_topdir $(PWD)/rpm' --define 'dist .Suse' -ba $(NAME).Suse.spec )

locale_install : locale
	for file in $(PO); do \
         dummy=$${file#*/}; \
         dummy2=$${dummy#*-}; \
         lang=$${dummy2%%.po}; \
         $(MKPATH) $(DESTDIR)$(LOCALEDIR)/$$lang/LC_MESSAGES; \
         $(CP) $$lang/LC_MESSAGES/$(NAME).mo \
                              $(DESTDIR)$(LOCALEDIR)/$$lang/LC_MESSAGES; \
         $(CHMOD) 755 $(DESTDIR)$(LOCALEDIR)/$$lang/LC_MESSAGES; \
         done

$(DESTDIR)$(SHAREDIR)/$(NAME) :
	$(MKPATH) $(DESTDIR)$(SHAREDIR)/$(NAME)

icon_install : $(DESTDIR)$(SHAREDIR)/$(NAME)
	$(MKPATH) $(DESTDIR)$(SHAREDIR)/applications
	$(MKPATH) $(DESTDIR)$(SHAREDIR)/pixmaps
	$(CP) $(NAME).desktop $(DESTDIR)$(SHAREDIR)/applications
	$(CP) $(NAME).svg stock-rotate-90.svg stock-rotate-180.svg \
	      stock-rotate-270.svg scanner.svg pdf.svg \
	      stock-selection-all-16.png $(DESTDIR)$(SHAREDIR)/$(NAME)
	$(CP) $(NAME).svg $(DESTDIR)$(SHAREDIR)/pixmaps


html : htdocs/index.html

pot : po/$(NAME).pot

po.tar.gz : po/$(NAME).pot $(PO)
	cd po; tar cfvz po.tar.gz $(NAME).pot *.po
	mv po/po.tar.gz .

locale : $(PO)
	for file in $(PO); do \
         msgfmt -c $$file; \
         dummy=$${file#*/}; \
         dummy2=$${dummy#*-}; \
         lang=$${dummy2%%.po}; \
         $(MKPATH) $$lang/LC_MESSAGES; \
         mv messages.mo $$lang/LC_MESSAGES/$(NAME).mo; \
         done

$(NAME).spec : bin/$(NAME) debian/changelog
	$(CP) $(NAME).spec $(NAME).spec_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < $(NAME).spec_tmp | \
         sed '/^%changelog/q' > $(NAME).spec
	rm $(NAME).spec_tmp
	echo "*" `date +'%a %b %d %Y'` "$(AUTHOR) <$(EMAIL)>" >> $(NAME).spec
	sed 's/^$(NAME).*//' < debian/changelog | \
         sed 's/^ --.*//' | sed 's/^  \*/  -/' | sed '/^$$/d' >> $(NAME).spec

$(NAME).Suse.spec : bin/$(NAME) debian/changelog
	$(CP) $(NAME).Suse.spec $(NAME).spec_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < $(NAME).spec_tmp | \
         sed '/^%changelog/q' > $(NAME).Suse.spec
	rm $(NAME).spec_tmp
	echo "*" `date +'%a %b %d %Y'` "$(AUTHOR) <$(EMAIL)>" >> $(NAME).Suse.spec
	sed 's/^$(NAME).*//' < debian/changelog | \
         sed 's/^ --.*//' | sed 's/^  \*/  -/' | sed '/^$$/d' >> $(NAME).Suse.spec

ppa : tardist
	$(RM_RF) /tmp/$(NAME)
	$(MKPATH) /tmp/$(NAME)
	cp $(NAME)-$(VERSION).tar.gz /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.gz
	cd /tmp/$(NAME) && tar xvfz $(NAME)_$(VERSION).orig.tar.gz
	cd /tmp/$(NAME)/$(NAME)-$(VERSION) && debuild -S -sa
	dput $(NAME)-ppa /tmp/$(NAME)/$(NAME)_$(VERSION)_source.changes

debdist : tardist
	$(RM_RF) /tmp/$(NAME)
	$(MKPATH) /tmp/$(NAME)
	cp $(NAME)-$(VERSION).tar.gz /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.gz
	cd /tmp/$(NAME) && tar xvfz $(NAME)_$(VERSION).orig.tar.gz
	cd /tmp/$(NAME)/$(NAME)-$(VERSION) && debuild
	$(CP) /tmp/$(NAME)/$(NAME)_$(VERSION)_all.deb \
              /tmp/$(NAME)/$(NAME)_$(VERSION).diff.gz \
              /tmp/$(NAME)/$(NAME)_$(VERSION).dsc \
              /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.gz .

htdocs/index.html : bin/$(NAME)
	[ -d htdocs ] || mkdir htdocs
	pod2html --noindex --title=$(NAME)-$(VERSION) bin/$(NAME) > htdocs/index.html

remote-html : htdocs/index.html
	scp htdocs/index.html ra28145,$(NAME)@web.sf.net:/home/groups/g/gs/$(NAME)/htdocs/

file_releases : 
	scp $(NAME)-$(VERSION).tar.gz \
         rpm/RPMS/noarch/$(NAME)-$(VERSION)* \
         rpm/SRPMS/$(NAME)-$(VERSION)* \
         /tmp/$(NAME)/$(NAME)_$(VERSION)*.deb \
	  ra28145,$(NAME)@frs.sf.net:/home/frs/project/g/gs/$(NAME)/$(NAME)/$(VERSION)/

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
