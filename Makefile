DEB_HOST_GNU_TYPE ?=$(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)

all: migrator oodfinder componentcleaner systemscanner sourcefinder repochecker processdebdiff testversions cruftprocessor binarytosource binnmuscheduler

migrator: migrator.dpr *.pas
	fpc -Sd -gl migrator.dpr

oodfinder: oodfinder.dpr *.pas
	fpc -Sd -gl oodfinder.dpr

componentcleaner: componentcleaner.dpr *.pas
	fpc -Sd -gl componentcleaner.dpr

systemscanner: systemscanner.dpr *.pas
	fpc -Sd -gl systemscanner.dpr

sourcefinder: sourcefinder.dpr *.pas
	fpc -Sd -gl sourcefinder.dpr

repochecker: repochecker.dpr *.pas
	fpc -Sd -gl repochecker.dpr

processdebdiff: processdebdiff.dpr *.pas
	fpc -Sd -gl processdebdiff.dpr

testversions: testversions.dpr *.pas
	fpc -Sd -gl testversions.dpr

cruftprocessor: cruftprocessor.dpr *.pas
	fpc -Sd -gl cruftprocessor.dpr

binarytosource: binarytosource.dpr *.pas
	fpc -Sd -gl binarytosource.dpr

binnmuscheduler: binnmuscheduler.dpr *.pas
	fpc -Sd -gl binnmuscheduler.dpr


clean:
	rm oodfinder componentcleaner repochecker migrator sourcefinder systemscanner processdebdiff *.o *.ppu
