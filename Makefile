SHELL = /bin/sh

program = gscan2pdf
version = $(shell awk '{if (match($$0, /my \$$version = "(.*)";/, a)) print a[1]}' $(program))

tar : gscan2pdf-$(version).tar.gz

$(program) : ;

install : $(program)
	cp $(program) /usr/local/bin

uninstall : $(program)
	rm /usr/local/bin/$(program)

gscan2pdf-$(version).tar.gz : $(program)
	mkdir --parents ../gscan2pdf-$(version)/deb
	cp Makefile INSTALL LICENSE COPYING ../gscan2pdf-$(version)
	cp deb/debian-binary deb/control ../gscan2pdf-$(version)/deb
	cd .. ; tar cfvz gscan2pdf-$(version).tar.gz gscan2pdf-$(version)
	mv ../gscan2pdf-$(version).tar.gz .
	rm -r ../gscan2pdf-$(version)

deb/control : $(program)
	cp deb/control deb/control_tmp
	awk '{if (/^Version:/) print "Version: $(version)" ; else print}' \
         deb/control_tmp > deb/control
	rm deb/control_tmp

dist : $(program) deb/control tmp
	cd tmp ; md5sum $(shell find tmp -type f | awk '/.\// { print substr($$0, 5) }') > DEBIAN/md5sums
	dpkg-deb -b tmp gscan2pdf-$(version).deb

tmp : $(program) deb/control
	mkdir --parents tmp/DEBIAN tmp/usr/bin
	cp deb/control tmp/DEBIAN
	cp $(program) tmp/usr/bin

clean :
	rm -r gscan2pdf_$(version).deb* tmp gscan2pdf_$(version).tar.gz
