#!/usr/bin/env ruby
# encoding: utf-8
require "rubygems"

spec = Gem::Specification.new do |s|
  s.name="nysol-take"
  s.version="3.0.0"
  s.author="NYSOL"
  s.email="info@nysol.jp"
  s.homepage="http://www.nysol.jp/"
  s.summary="nysol TAKE tools"
	s.extensions = [
		'ext/lcmrun/extconf.rb','ext/lcmseqrun/extconf.rb',
		'ext/lcmseq0run/extconf.rb','ext/lcmtransrun/extconf.rb',
		'ext/grhfilrun/extconf.rb','ext/sspcrun/extconf.rb',
		'ext/macerun/extconf.rb'
	]
	s.files=Dir.glob([
		"ext/lcmrun/extconf.rb",
		"ext/lcmrun/lcmrun.cpp",
		"ext/lcmseqrun/extconf.rb",
		"ext/lcmseqrun/lcmseqrun.cpp",
		"ext/lcmseq0run/extconf.rb",
		"ext/lcmseq0run/lcmseq0run.cpp",
		"ext/grhfilrun/extconf.rb",
		"ext/grhfilrun/grhfilrun.c",
		"ext/sspcrun/extconf.rb",
		"ext/sspcrun/sspcrun.cpp",
		"ext/macerun/extconf.rb",
		"ext/macerun/macerun.cpp",
		"ext/lcmrun/src/*.c",
		"ext/lcmrun/src/*.h",
		"ext/lcmseqrun/src/*.c",
		"ext/lcmseqrun/src/*.h",
		"ext/lcmseq0run/src/*.c",
		"ext/lcmseq0run/src/*.h",
		"ext/sspcrun/src/*.c",
		"ext/sspcrun/src/*.h",
		"ext/macerun/src/*.c",
		"ext/macerun/src/*.h",
		"ext/grhfilrun/src/*.c",
		"ext/grhfilrun/src/*.h",
		"ext/lcmtransrun/extconf.rb",
		"ext/lcmtransrun/lcmtransrun.cpp",
		"lib/nysol/enumLcmEp.rb",
		"lib/nysol/enumLcmEsp.rb",
		"lib/nysol/enumLcmIs.rb",
		"lib/nysol/enumLcmSeq.rb",
		"lib/nysol/items.rb",
		"lib/nysol/seqDB.rb",
		"lib/nysol/taxonomy.rb",
		"lib/nysol/traDB.rb",
		"lib/nysol/take.rb",
		"bin/mclique.rb",
		"bin/mbiclique.rb",
		"bin/mbipolish.rb",
		"bin/mclique2g.rb",
		"bin/mcliqueInfo.rb",
		"bin/mgdiff.rb",
		"bin/mitemset.rb",
		"bin/mpolishing.rb",
		"bin/msequence.rb",	
		"bin/mfriends.rb",	
		"bin/mccomp.rb",	
		"bin/mhifriend.rb",
		"bin/mhipolish.rb",
		"bin/mpal.rb",
		"bin/mtra2gc.rb",
		"bin/mtra2g.rb"
	])
	s.bindir = 'bin'
	s.executables = [
		"mclique.rb",
		"mbiclique.rb",
		"mbipolish.rb",
		"mclique2g.rb",
		"mcliqueInfo.rb",
		"mgdiff.rb",	
		"mitemset.rb",
		"mpolishing.rb",
		"msequence.rb",
		"mfriends.rb",	
		"mccomp.rb",	
		"mhifriend.rb",
		"mhipolish.rb",
		"mpal.rb",
		"mtra2gc.rb",
		"mtra2g.rb"
	]
	s.require_path = "lib"
	s.description = <<-EOF
    nysol TAKE tools
	EOF

end
