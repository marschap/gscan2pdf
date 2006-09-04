SHELL = /bin/sh

program = gscan2pdf
version = $(shell awk '{if (match($$0, /my \$$version = "(.*)";/, a)) print a[1]}' $(program))

tar : $(program)-$(version).tar.gz

$(program) : ;

install : $(program)
	cp $(program) /usr/local/bin

uninstall : $(program)
	rm /usr/local/bin/$(program)

$(program)-$(version).tar.gz : $(program)
	mkdir --parents ../$(program)-$(version)/deb
	cp $(program) Makefile INSTALL LICENSE COPYING ../$(program)-$(version)
	cp deb/debian-binary deb/control ../$(program)-$(version)/deb
	cd .. ; tar cfvz $(program)-$(version).tar.gz $(program)-$(version)
	mv ../$(program)-$(version).tar.gz .
	rm -r ../$(program)-$(version)

deb/control : $(program)
	cp deb/control deb/control_tmp
	awk '{if (/^Version:/) print "Version: $(version)" ; else print}' \
         deb/control_tmp > deb/control
	rm deb/control_tmp

dist : $(program) deb/control tmp
	cd tmp ; md5sum $(shell find tmp -type f | awk '/.\// { print substr($$0, 5) }') > DEBIAN/md5sums
	dpkg-deb -b tmp $(program)-$(version).deb

tmp : $(program) deb/control
	mkdir --parents tmp/DEBIAN tmp/usr/bin
	cp deb/control tmp/DEBIAN
	cp $(program) tmp/usr/bin

clean :
	rm -r $(program)-$(version).deb* tmp $(program)-$(version).tar.gz
