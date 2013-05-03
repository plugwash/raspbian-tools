DEB_HOST_GNU_TYPE ?=$(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)

all: migrator oodfinder componentcleaner systemscanner sourcefinder repochecker processdebdiff

migrator: migrator.dpr *.pas
	fpc -Sd -gl migrator.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/

oodfinder: oodfinder.dpr *.pas
	fpc -Sd -gl oodfinder.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/

componentcleaner: componentcleaner.dpr *.pas
	fpc -Sd -gl componentcleaner.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/

systemscanner: systemscanner.dpr *.pas
	fpc -Sd -gl systemscanner.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/

sourcefinder: sourcefinder.dpr *.pas
	fpc -Sd -gl sourcefinder.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/

repochecker: repochecker.dpr *.pas
	fpc -Sd -gl repochecker.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/

processdebdiff: processdebdiff.dpr *.pas
	fpc -Sd -gl processdebdiff.dpr -Fl/usr/lib/gcc/$(DEB_HOST_GNU_TYPE)/4.4.5/


clean:
	rm oodfinder componentcleaner repochecker migrator sourcefinder systemscanner processdebdiff *.o *.ppu
