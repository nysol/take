require "rubygems"
require "mkmf"

unless have_library("kgmod3")
  puts("need libkgmod.")
  puts("refer https://github.com/nysol/mcmd")
  exit 1
end


cp = "$(srcdir)"

$CFLAGS = " -O3 -Wall -I. -I#{cp}/src -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"
$CPPFLAGS = " -O3 -Wall -I. -I#{cp}/src  -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"
$CXXFLAGS = " -O3 -Wall -I. -I#{cp}/src  -DB_STATIC -D_NO_MAIN_ -DLINE -fPIC -Wno-error=format-security"

$LOCAL_LIBS += " -lstdc++ -lkgmod3"

create_makefile("nysol/lcmseqrun")

