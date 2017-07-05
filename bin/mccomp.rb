#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# 1.0 initial development: 2016/10/17
# 1.1 出力のnode項目名をnf=の値にする: 2016/11/11
$cmd="mccomp2g.rb"
$version="1.1"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) 連結成分を出力する

用法) #{$cmd} ei= ef= [ni=] [nf=] [o=] [T=] [-verbose] [-mcmdenv] [--help]

  ファイル名指定
  ei=    : 枝データファイル
  ef=    : 枝データ上の2つの節点項目名(省略時は"node1,node2")
  ni=    : 節点データファイル
  nf=    : 節点データ上の節点項目名(省略時は"node")
  o=     : 出力ファイル(連結成分ID-枝:-nodeを指定することでクリークID-節点に変更可能,省略時は標準出力)

  その他
  T= : ワークディレクトリ(default:/tmp)
  -verbose : Rの実行ログを出力
  --help : ヘルプの表示

入力形式)
一般グラフを節点ペアで表現した形式。

o=の出力形式)
節点と連結成分IDを出力する。
出力項目は"id,node,size"の3項目である。
sizeは連結成分を構成する節点数である。

例)
$ cat data/edge.csv 
n1,n2
a,d
a,e
b,f
d,e
f,g
g,b
g,h

$ #{$cmd} ei=edge.csv ef=n1,n2 o=output.csv
##END# #{$cmd} ei=edge.csv ef=n1,n2 -node o=output.csv
$ cat output.csv 
id%0,node,size
1,a,3
1,d,3
1,e,3
2,b,4
2,f,4
2,g,4
2,h,4

例) 節点ファイルも指定した例
$ cat node.csv 
n
a
b
c
d
e
f
g
h

$ #{$cmd} ei=edge.csv ef=n1,n2 ni=node.csv nf=n o=output.csv
#END# #{$cmd} ei=edge.csv o=output.csv ef=n1,n2 ni=node.csv nf=n
$ cat output.csv 
id%0,node,size
1,a,3
1,d,3
1,e,3
2,b,4
2,f,4
2,g,4
2,h,4
3,c,1
4,i,1

# Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
	$revision ="0" if $revision =~ /VERSION/
	STDERR.puts "version #{$version} revision #{$revision}"
	exit
end

help() if ARGV.size <= 0 or ARGV[0]=="--help"
ver() if ARGV[0]=="--version"

args=MCMD::Margs.new(ARGV,"ei=,ef=,ni=,nf=,o=,-verbose","ei=,ef=")

# Rライブラリ実行可能確認
exit(1) unless(MCMD::chkRexe("igraph"))

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

ei = args. file("ei=","r") # edgeファイル名
ni = args. file("ni=","r") # node file name

# ---- edge field names (two nodes) on ei=
ef1,ef2 = args.field("ef=", ei, "node1,node2",2,2)["names"]

# ---- node field name on ni=
nf = args.field("nf=", ni, "node",1,1)
nf = nf["names"][0] if nf

oFile   = args.file("o=", "w")

def genRscript(eFile,oFile,cidFile,scpFile)
	r_proc = <<EOF
library(igraph)
## reading edge file
g=read.graph("#{eFile}",format="edgelist",directed=FALSE)
c=components(g)
seq=0:(length(c$membership)-1)
dat=data.frame(id=c$membership,nid=seq,size=c$csize[c$membership])
write.csv(dat,file="#{oFile}",quote=FALSE,row.names = FALSE)
write.table(max(c$membership),file="#{cidFile}",col.names = FALSE,row.names = FALSE)
EOF

	File.open(scpFile,"w"){|fpw|
		fpw.write(r_proc)
	}
end


def conv2num(eFile,nFile,ef1,ef2,nf,numFile,mapFile,isoFile)

	wf=MCMD::Mtemp.new
	xxn1=wf.file
	xxn2=wf.file
	xxn3=wf.file
	xxeNodeMF=wf.file

	# create a nodes list that are included in node and edge data
	system "mcut f=#{ef1}:node i=#{eFile} o=#{xxn1}"
	system "mcut f=#{ef2}:node i=#{eFile} o=#{xxn2}"
	unless nFile
		system "echo node >#{xxn3}"
	else
		system "mcut f=#{nf}:node  i=#{nFile} o=#{xxn3}"
	end

	# xxeNodeMF : nodes list that are included in edge
	system "mcat i=#{xxn1},#{xxn2} | muniq k=node | msetstr v=1 a=eNode o=#{xxeNodeMF}"

	# isolate nodes list
	system "mcat i=#{xxn1},#{xxn2},#{xxn3} | mcommon k=node m=#{xxeNodeMF} -r | mcut f=node o=#{isoFile}"

	# create a mapping table between the original node label and the number iGraph will use
	f=""
	f << "mcat i=#{xxn1},#{xxn2},#{xxn3} |"
	f << "muniq k=node |"
	f << "mjoin k=node m=#{xxeNodeMF} f=eNode |"
	f << "mnullto f=eNode v=0 |"
	f << "mnumber s=eNode%r,node a=nid o=#{mapFile}" 
	system(f)

	# create a data file that R script read
	f=""
	f << "mjoin k=#{ef1} K=node m=#{mapFile} f=nid:nid1 i=#{eFile} |"
	f << "mjoin k=#{ef2} K=node m=#{mapFile} f=nid:nid2 |"
	f << "mcut  f=nid1,nid2 -nfno |"
	f << "tr ',' ' ' >#{numFile}"
	system(f)
end

temp=MCMD::Mtemp.new
numFile=temp.file
mapFile=temp.file
isoFile=temp.file
cluFile=temp.file
cidFile=temp.file
scpFile=temp.file
iscFile=temp.file
clnFile=temp.file
conv2num(ei,ni,ef1,ef2,nf,numFile,mapFile,isoFile)
genRscript(numFile,cluFile,cidFile,scpFile)

if args.bool("-verbose") then
	system "R --vanilla -q < #{scpFile} "
else
	system "R --vanilla -q  --slave < #{scpFile} 2>/dev/null"
end
cid=`cat #{cidFile}`.to_i

f=""
f << "mnumber s=node S=#{cid+1} a=id i=#{isoFile} |"
f << "msetstr v=1 a=size |"
f << "mcut f=id,node,size o=#{iscFile}"
system(f)

# #{cluFile}
# id,nid,size
# 1,0,3
# 2,1,4
# 1,2,3
# 1,3,3
# 2,4,4
# 2,5,4
# 2,6,4
f=""
f << "mjoin k=nid m=#{mapFile} i=#{cluFile} f=node |"
f << "mcut f=id,node,size o=#{clnFile}"
system(f)

f=""
f << "mcat i=#{clnFile},#{iscFile} |"
f << "mfldname f=node:#{nf} |" if nf
f << "msortf f=id o=#{oFile}"
system(f)

# end message
MCMD::endLog(args.cmdline)

