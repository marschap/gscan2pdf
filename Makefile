SHELL = /bin/sh

program = gscan2pdf
version = $(shell awk '{if (match($$0, /my \$$version = "(.*)";/, a)) print a[1]}' $(program))

tar : $(program)-$(version).tar.gz

dist : htdocs/download/debian/binary/$(program)-$(version).deb

web : htdocs/index.html

$(program) : ;

install : $(program)
	cp $(program) /usr/local/bin

uninstall : $(program)
	rm /usr/local/bin/$(program)

$(program)-$(version).tar.gz : $(program)
	mkdir --parents ../$(program)-$(version)/deb
	cp $(program) $(program).pot Makefile INSTALL LICENSE COPYING ../$(program)-$(version)
	cp deb/debian-binary deb/control ../$(program)-$(version)/deb
	cd .. ; tar cfvz $(program)-$(version).tar.gz $(program)-$(version)
	mv ../$(program)-$(version).tar.gz .
	rm -r ../$(program)-$(version)

deb/control : $(program)
	cp deb/control deb/control_tmp
	awk '{if (/^Version:/) print "Version: $(version)" ; else print}' \
         deb/control_tmp > deb/control
	rm deb/control_tmp

htdocs/download/debian/binary/$(program)-$(version).deb : $(program) deb/control tmp
	cd tmp ; md5sum $(shell find tmp -type f | \
                        awk '/.\// { print substr($$0, 5) }') > DEBIAN/md5sums
	dpkg-deb -b tmp $(program)-$(version).deb
	cp $(program)-$(version).deb htdocs/download/debian/binary

htdocs/download/debian/binary/Packages.gz : htdocs/download/debian/binary/$(program)-$(version).deb
	cd htdocs/download/debian ; \
         dpkg-scanpackages binary /dev/null | gzip -9c > binary/Packages.gz

tmp : $(program) deb/control
	mkdir --parents tmp/DEBIAN tmp/usr/bin
	cp deb/control tmp/DEBIAN
	cp $(program) tmp/usr/bin

remote-dist : download/debian/binary/$(program)-$(version).deb download/debian/binary/Packages.gz
	scp htdocs/download/debian/binary/$(program)-$(version).deb \
            htdocs/download/debian/binary/Packages.gz \
	    ra28145@shell.sf.net:/home/groups/g/gs/gscan2pdf/htdocs/download/debian/binary

htdocs/index.html : $(program)
	pod2html --title=$(program)-$(version) $(program) > htdocs/index.html

remote-web : htdocs/index.html
	scp htdocs/index.html ra28145@shell.sf.net:/home/groups/g/gs/gscan2pdf/htdocs/

clean :
	rm -r $(program)-$(version).deb* tmp $(program)-$(version).tar.gz
