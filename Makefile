SHELL = /bin/sh

version=0.5

gscan2pdf : ;

install : gscan2pdf
	cp gscan2pdf /usr/local/bin

uninstall : gscan2pdf
	rm /usr/local/bin/gscan2pdf

tar : gscan2pdf
	cd .. ; tar cfvz gscan2pdf.tar.gz gscan2pdf/gscan2pdf \
         gscan2pdf/Makefile \
         gscan2pdf/INSTALL gscan2pdf/LICENSE gscan2pdf/COPYING \
         gscan2pdf/deb/debian-binary gscan2pdf/deb/control

dist	 : gscan2pdf
	mkdir --parents tmp/DEBIAN tmp/usr/bin
	cp deb/control tmp/DEBIAN
	cp gscan2pdf tmp/usr/bin
	dpkg-deb -b tmp gscan2pdf_$(version).deb

clean :
	rm -r gscan2pdf_$(version).deb tmp ../gscan2pdf.tar.gz
