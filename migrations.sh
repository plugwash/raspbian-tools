#removals for source migration sdl-stretch 0.3.1-3
reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=armhf remove wheezy libsdl-stretch-0-3
reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=armhf remove wheezy libsdl-stretch-dev

#source migration libheimdal-kadm5-perl 0.08-4+rpi1
reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=source copy wheezy wheezy-staging libheimdal-kadm5-perl
reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=armhf copy wheezy wheezy-staging libheimdal-kadm5-perl

#source migration sdl-stretch 0.3.1-3
reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=source copy wheezy wheezy-staging sdl-stretch

reprepro -V --basedir . --morguedir +b/morgue export wheezy
