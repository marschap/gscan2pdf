SHELL = /bin/sh

program = gscan2pdf
version = $(shell awk '{if (match($$0, /my \$$version = "(.*)";/, a)) print a[1]}' $(program))
year = $(shell date +%Y)
author = Jeffrey Ratcliffe
email = ra28145@users.sourceforge.net

BIN_DIR = /usr/local/bin
LOCALE = .

DEB_BIN = /usr/bin
DEB_LOCALE = /usr/share/locale

PO = $(wildcard po/*.po)

tar : $(program)-$(version).tar.gz

dist : htdocs/download/debian/binary/$(program)-$(version).deb

web : htdocs/index.html

pot : po/$(program).pot

po.tar.gz : po/$(program).pot $(PO)
	cd po; tar cfvz po.tar.gz $(program).pot *.po
	mv po/po.tar.gz .

locale : $(LOCALE)/*/LC_MESSAGES/$(program).mo

$(program) : ;

install : $(BIN_DIR)/$(program) $(LOCALE)/*/LC_MESSAGES/$(program).mo

uninstall : $(program)
	rm $(BIN_DIR)/$(program) $(LOCALE)/*/LC_MESSAGES/$(program).mo

$(BIN_DIR)/$(program) : $(program)
	cp $(program) $(BIN_DIR)

tmp$(DEB_LOCALE)/%/LC_MESSAGES/$(program).mo : $(LOCALE)/*/LC_MESSAGES/$(program).mo
	path=$@; \
         dir1=$${path%/*}; \
	 dir2=$${dir1%/*}; \
	 locale=$${dir2##*/}; \
         mkdir --parents tmp$(DEB_LOCALE)/$$locale/LC_MESSAGES; \
         cp $(LOCALE)/$$locale/LC_MESSAGES/$(program).mo \
	                                  tmp$(DEB_LOCALE)/$$locale/LC_MESSAGES

$(LOCALE)/%/LC_MESSAGES/$(program).mo : $(PO)
	for file in $(PO); do \
         msgfmt $$file; \
         po=$${file#*/}; \
         mkdir --parents $(LOCALE)/$${po%%.po}/LC_MESSAGES; \
         mv messages.mo $(LOCALE)/$${po%%.po}/LC_MESSAGES/$(program).mo; \
         done

$(program)-$(version).tar.gz : $(program) Makefile INSTALL LICENSE COPYING po/$(program).pot $(PO)
	mkdir --parents ../$(program)-$(version)/deb ../$(program)-$(version)/po
	cp $(program) Makefile INSTALL LICENSE COPYING ../$(program)-$(version)
	cp $(PO) po/$(program).pot ../$(program)-$(version)/po
	cp deb/debian-binary deb/control ../$(program)-$(version)/deb
	cd .. ; tar cfvz $(program)-$(version).tar.gz $(program)-$(version)
	mv ../$(program)-$(version).tar.gz .
	rm -r ../$(program)-$(version)

deb/control : $(program)
	cp deb/control deb/control_tmp
	awk '{if (/^Version:/) print "Version: $(version)" ; else print}' \
         deb/control_tmp > deb/control
	rm deb/control_tmp

htdocs/download/debian/binary/$(program)-$(version).deb : tmp/DEBIAN/md5sums
	dpkg-deb -b tmp $(program)-$(version).deb
	cp $(program)-$(version).deb htdocs/download/debian/binary

tmp/DEBIAN/md5sums : $(program) deb/control \
                     $(wildcard tmp$(DEB_LOCALE)/*/LC_MESSAGES/$(program).mo)
	mkdir --parents tmp/DEBIAN tmp$(DEB_BIN) tmp$(DEB_LOCALE)
	cp deb/control tmp/DEBIAN
	cp $(program) tmp$(DEB_BIN)
	cd tmp ; md5sum $(shell find tmp -type f | \
                        awk '/.\// { print substr($$0, 5) }') > DEBIAN/md5sums

htdocs/download/debian/binary/Packages.gz : htdocs/download/debian/binary/$(program)-$(version).deb
	cd htdocs/download/debian ; \
         dpkg-scanpackages binary /dev/null | gzip -9c > binary/Packages.gz

remote-dist : htdocs/download/debian/binary/$(program)-$(version).deb htdocs/download/debian/binary/Packages.gz
	scp htdocs/download/debian/binary/$(program)-$(version).deb \
            htdocs/download/debian/binary/Packages.gz \
	    ra28145@shell.sf.net:/home/groups/g/gs/gscan2pdf/htdocs/download/debian/binary

htdocs/index.html : $(program)
	pod2html --title=$(program)-$(version) $(program) > htdocs/index.html

remote-web : htdocs/index.html
	scp htdocs/index.html ra28145@shell.sf.net:/home/groups/g/gs/gscan2pdf/htdocs/

po/$(program).pot : $(program)
	xgettext -L perl --keyword=get -o - $(program) | \
         sed 's/SOME DESCRIPTIVE TITLE/messages.pot for $(program)/' | \
         sed 's/PACKAGE VERSION/$(program)-$(version)/' | \
         sed "s/YEAR THE PACKAGE'S COPYRIGHT HOLDER/$(year) $(author)/" | \
         sed 's/PACKAGE/$(program)/' | \
         sed 's/FIRST AUTHOR <EMAIL@ADDRESS>, YEAR/$(author) <$(email)>, $(year)/' | \
         sed 's/Report-Msgid-Bugs-To: /Report-Msgid-Bugs-To: $(email)/' \
         > $@

clean :
	rm -r $(program)-$(version).deb* tmp $(program)-$(version).tar.gz
