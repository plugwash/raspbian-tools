all: migrator oodfinder componentcleaner systemscanner sourcefinder repochecker

migrator: migrator.dpr *.pas
	fpc -Sd -gv migrator.dpr -Fl/usr/lib/gcc/i486-linux-gnu/4.4.5/

oodfinder: oodfinder.dpr *.pas
	fpc -Sd -gl oodfinder.dpr -Fl/usr/lib/gcc/i486-linux-gnu/4.4.5/

componentcleaner: componentcleaner.dpr *.pas
	fpc -Sd -gl componentcleaner.dpr -Fl/usr/lib/gcc/i486-linux-gnu/4.4.5/

systemscanner: systemscanner.dpr *.pas
	fpc -Sd -gl systemscanner.dpr -Fl/usr/lib/gcc/i486-linux-gnu/4.4.5/

sourcefinder: sourcefinder.dpr *.pas
	fpc -Sd -gl sourcefinder.dpr -Fl/usr/lib/gcc/i486-linux-gnu/4.4.5/

repochecker: repochecker.dpr *.pas
	fpc -Sd -gl repochecker.dpr -Fl/usr/lib/gcc/i486-linux-gnu/4.4.5/

clean:
	rm componentcleaner repochecker migrator sourcefinder systemscanner *.o *.ppu
