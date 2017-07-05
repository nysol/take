require "rubygems"
require "mkmf"


cp = "$(srcdir)"
$CFLAGS = " -O3 -Os -s -w -I. -I#{cp}/src -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"
$CPPFLAGS = " -O3 -Os -s -w -I. -I#{cp}/src  -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"
$CXXFLAGS = " -O3 -Os -s -w -I. -I#{cp}/src  -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"


create_makefile("nysol/grhfilrun")

