use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $program = "gscan2pdf";
my $year    = (localtime)[5] + 1900;
my $author  = "Jeffrey Ratcliffe";
my $email   = 'ra28145@users.sourceforge.net';

# Slurp the program source and dig out the version number.
my $text = do { local ( @ARGV, $/ ) = "bin/$program"; <> };
my $version = $1 if ( $text =~ /^my \$VERSION\s*=\s*'(.*)'/m );

my @argv = @ARGV;
my $prefixdir;
my $sharedir;
my $shareinstdir;

@ARGV = ();
for (@argv) {
    if (m!PREFIX=(.+)!i) {
        $prefixdir = $1;
        push @ARGV, $_;
    }
    elsif (m!SHAREINSTDIR=(.+)!i) {
        $shareinstdir = $1;
    }
    elsif (m!SHAREDIR=(.+)!i) {
        $sharedir = $1;
    }
    else {
        push @ARGV, $_;
    }
}

$prefixdir = "/usr"                unless ($prefixdir);
$sharedir  = $prefixdir . "/share" unless ($sharedir);
$localedir = $sharedir . "/locale" unless ($localedir);

WriteMakefile(
    NAME      => $program,
    VERSION   => $version,
    EXE_FILES => [ "bin/$program", 'bin/scanimage-perl', 'bin/scanadf-perl' ],
    PREREQ_PM => {
        Glib                   => 1.210,
        Gtk2                   => 1.090,
        Sane                   => 0.05,
        Gtk2::Ex::Simple::List => 0,
        Gtk2::ImageView        => 0,
        Image::Magick          => 0,
        IPC::Run3              => 0,
        Locale::gettext        => 1.05,
        Config::General        => 2.40,
        PDF::API2              => 0,
        Set::IntSpan           => 1.10,
        Goo::Canvas            => 0,
        Readonly               => 0,
        Log::Log4perl          => 0,
        Try::Tiny              => 0,
        List::MoreUtils        => 0,
        Filesys::Df            => 0,
    },
    clean => { FILES    => '$(SOURCE_TIDY)' },
    dist  => { COMPRESS => 'xz -9', SUFFIX => '.xz', },
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM => "bin/$program",     # retrieve abstract from module
            AUTHOR        => "$author <$email>"
          )
        : ()
    ),
);

sub MY::macro {
    my $self   = shift;
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
    my $self   = shift;
    my $string = $self->MM::install();
    $string =~ s/doc_install/doc_install locale_install icon_install/;
    return $string;
}

sub MY::postamble {
    my $postamble = <<'END';
SHELL = bash
DEB_BUILD_ROOT = /var/tmp/$(NAME)-$(VERSION)
MANIFEST = $(shell cat MANIFEST)
SOURCE = $(filter bin/% %.pm %.PL %.pl %.t,$(MANIFEST))
SOURCE_TIDY = $(foreach file,$(SOURCE),$(file).tdy)
PO = $(filter %.po,$(MANIFEST))
LANGUAGES = $(patsubst po/$(NAME)-%.po,%,$(PO))
MO = $(foreach lang,$(LANGUAGES),$(DESTDIR)$(LOCALEDIR)/$(lang)/LC_MESSAGES/$(NAME).mo)
ICONS = $(wildcard icons/*)

rpmdist : $(NAME).spec $(NAME).Suse.spec tardist
	$(MKPATH) rpm rpm/SPECS rpm/SOURCES rpm/BUILD rpm/RPMS rpm/SRPMS \
                                                  rpm/RPMS/noarch || /bin/true
	$(CP) $(NAME).spec $(NAME).Suse.spec rpm/SPECS/
	$(CP) $(NAME)-$(VERSION).tar.xz rpm/SOURCES/$(NAME)-$(VERSION).tar.xz
	( cd rpm/SPECS; \
	  rpmbuild --nodeps --define='_topdir $(PWD)/rpm' -ba $(NAME).spec; \
	  rpmbuild --nodeps --define='_topdir $(PWD)/rpm' --define 'dist .Suse' -ba $(NAME).Suse.spec )

locale_install : $(MO)

$(DESTDIR)$(LOCALEDIR)/%/LC_MESSAGES/$(NAME).mo : po/$(NAME)-%.po
	$(MKPATH) $(@D)
	msgfmt -c $< -o $@
	$(CHMOD) 755 $(@D)

$(DESTDIR)$(SHAREDIR)/$(NAME) $(DESTDIR)$(SHAREDIR)/applications $(DESTDIR)$(SHAREDIR)/pixmaps $(DESTDIR)$(SHAREDIR)/appdata :
	$(MKPATH) $@

icon_install : $(NAME).desktop $(ICONS) $(NAME).appdata.xml \
             | $(DESTDIR)$(SHAREDIR)/$(NAME) $(DESTDIR)$(SHAREDIR)/applications \
               $(DESTDIR)$(SHAREDIR)/pixmaps \
               $(DESTDIR)$(SHAREDIR)/appdata
	$(CP) $(NAME).desktop $(DESTDIR)$(SHAREDIR)/applications
	$(CP) $(ICONS) $(DESTDIR)$(SHAREDIR)/$(NAME)
	$(CP) icons/$(NAME).svg $(DESTDIR)$(SHAREDIR)/pixmaps
	$(CP) $(NAME).appdata.xml $(DESTDIR)$(SHAREDIR)/appdata

html : htdocs/index.html

pot : po/$(NAME).pot

po.tar.gz : po/$(NAME).pot $(PO)
	cd po; tar cfvz po.tar.gz $(NAME).pot *.po
	mv po/po.tar.gz .

$(NAME).spec $(NAME).Suse.spec : bin/$(NAME) debian/changelog
	$(CP) $@ $@_tmp
	sed 's/^Version:.*/Version: $(VERSION)/' < $@_tmp | \
         sed '/^%changelog/q' > $@
	rm $@_tmp
	echo "*" `date +'%a %b %d %Y'` "$(AUTHOR) <$(EMAIL)>" >> $@
	sed 's/^$(NAME).*//' < debian/changelog | \
         sed 's/^ --.*//' | sed 's/^  \*/  -/' | sed '/^$$/d' >> $@

debdist : tardist
	$(RM_RF) /tmp/$(NAME)
	$(MKPATH) /tmp/$(NAME)
	cp $(NAME)-$(VERSION).tar.xz /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.xz
	cd /tmp/$(NAME) && tar xvfJ $(NAME)_$(VERSION).orig.tar.xz
	cd /tmp/$(NAME)/$(NAME)-$(VERSION) && debuild
	$(CP) /tmp/$(NAME)/$(NAME)_$(VERSION)*_all.deb \
              /tmp/$(NAME)/$(NAME)_$(VERSION)*.dsc \
              /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.xz .

htdocs/index.html : bin/$(NAME)
	[ -d htdocs ] || mkdir htdocs
	pod2html --noindex --title=$(NAME)-$(VERSION) bin/$(NAME) > htdocs/index.html

remote-html : htdocs/index.html
	scp htdocs/index.html ra28145,$(NAME)@web.sf.net:/home/groups/g/gs/$(NAME)/htdocs/

file_releases :
	scp $(NAME)-$(VERSION).tar.xz \
         rpm/RPMS/noarch/$(NAME)-$(VERSION)* \
         rpm/SRPMS/$(NAME)-$(VERSION)* \
         /tmp/$(NAME)/$(NAME)_$(VERSION)*.deb \
	  ra28145,$(NAME)@frs.sf.net:/home/frs/project/g/gs/$(NAME)/$(NAME)/$(VERSION)/

po/$(NAME).pot : $(SOURCE)
	xgettext -L perl --keyword=get --from-code=UTF-8 -o - -f MANIFEST | \
         sed 's/SOME DESCRIPTIVE TITLE/messages.pot for $(NAME)/' | \
         sed 's/PACKAGE VERSION/$(NAME)-$(VERSION)/' | \
         sed "s/YEAR THE PACKAGE'S COPYRIGHT HOLDER/$(YEAR) $(AUTHOR)/" | \
         sed 's/PACKAGE/$(NAME)/' | \
         sed 's/FIRST AUTHOR <EMAIL@ADDRESS>, YEAR/$(AUTHOR) <$(EMAIL)>, $(YEAR)/' | \
         sed 's/Report-Msgid-Bugs-To: /Report-Msgid-Bugs-To: $(EMAIL)/' | \
         grep -v fuzzy > $@

MANIFEST : $(SOURCE)
	git ls-files | egrep -v '^\.(git|be)' > $@

tidy : MANIFEST $(SOURCE_TIDY)

%.tdy : %
	perltidy $* && if ! diff -q $@ $* > /dev/null; then cp $@ $*; fi
END
    $postamble;
}
