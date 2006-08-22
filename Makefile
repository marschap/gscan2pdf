SHELL = /bin/sh

version = $(shell awk '{if (match($$0, /my \$$version = (.*);/, a)) print a[1]}' $(program))
program = gscan2pdf

$(program) : ;

install : $(program)
	cp $(program) /usr/local/bin

uninstall : $(program)
	rm /usr/local/bin/$(program)

tar : $(program)
	cd .. ; tar cfvz gscan2pdf_$(version).tar.gz gscan2pdf/$(program) \
         gscan2pdf/Makefile \
         gscan2pdf/INSTALL gscan2pdf/LICENSE gscan2pdf/COPYING \
         gscan2pdf/deb/debian-binary gscan2pdf/deb/control
	mv ../gscan2pdf_$(version).tar.gz .

deb/control : $(program)
	cp deb/control deb/control_tmp
	awk '{if (/^Version:/) print "Version: $(version)" ; else print}' \
         deb/control_tmp > deb/control
	rm deb/control_tmp

dist : $(program) deb/control
	mkdir --parents tmp/DEBIAN tmp/usr/bin
	cp deb/control tmp/DEBIAN
	cp $(program) tmp/usr/bin
	cd tmp ; md5sum $(shell find tmp -type f | awk '/.\// { print substr($$0, 5) }') > DEBIAN/md5sums
	dpkg-deb -b tmp gscan2pdf_$(version).deb

clean :
	rm -r gscan2pdf_$(version).deb tmp gscan2pdf_$(version).tar.gz
