require "rubygems"
require "mkmf"


$CPPFLAGS += " -Wall"
$LOCAL_LIBS += " -lstdc++ "

cp = "$(srcdir)"

$CFLAGS = " -O3 -Wall -I. -I#{cp}/src -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"
$CPPFLAGS = " -O3 -Wall -I. -I#{cp}/src  -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"
$CXXFLAGS = " -O3 -Wall -I. -I#{cp}/src  -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"

$LOCAL_LIBS += " -lstdc++ -lkgmod3"


create_makefile("nysol/lcmtransrun")

