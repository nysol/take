#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# ver="1.0" # 初期リリース 2014/2/20
# ver="1.1" # 節点ファイル対応 2014/8/2
$cmd=$0.sub(/.*\//,"")
$version="1.1"
$revision="###VERSION###"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) ２つのグラフを比較し、同じ枝と異なる枝の情報を出力する。
書式) #{$cmd} ei= [ef=] eI= [eF=] [eo=] [no=] [T=] [--help]

  ファイル名指定
  ei=  : 入力枝ファイル1
  ef=  : 枝を構成するの2つの節点項目名(ei=上の項目名,デフォルト:node1,node2)
  eI=  : 入力枝ファイル2
  eF=  : eI=上の2つの節点項目名(ef=と同じであれば省略できる,デフォルト:ef=で指定した項目名)

  ni=  : 入力節点ファイル1(ei=に対応)
  nf=  : 枝を構成するの2つの節点項目名(ni=上の項目名,デフォルト:node)
  nI=  : 入力節点ファイル2(eI=に対応)
  nF=  : nI=上の2つの節点項目名(nf=と同じであれば省略できる,デフォルト:nf=で指定した項目名)

  eo=  : 出力枝ファイル
  no=  : 出力節点ファイル

	-dir : 有向グラフとして扱う

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

  注1) 無向グラフとして扱う場合(デフォルト)、ei=ファイルとeI=ファイルとで、
       節点の並びが異なっていても、それは同じと見なす(ex. 枝a,bと枝b,aは同じ)。
       -dirを指定すれば異なるものと見なす。
  注2) 無向グラフとして扱う場合(デフォルト)、
       処理効率を重視し、ef=で指定した節点の並びはアルファベット順に並べ替えるため、
       eo=の項目の並びがei=やeI=の並びと異なることがある。
  注3) 同じ枝が複数ある場合、それらは単一化される。

入力データ)
ei=,eI=: 節点ペアからなるCSVファイル。
ni=,nI=: 節点からなるCSVファイル。

枝出力データ)
枝ファイル1と枝ファイル2のいずれかに出現する枝(節点ペア)について以下の値を出力する。
項目名: 内容
 ei    : ei=で指定したグラフにその行の節点ペアがあれば、そのファイル名
 eI    : eI=で指定したグラフにその行の節点ペアがあれば、そのファイル名
 diff : 差分の区分
         1: ei=のグラフにしか存在しない
         0: ei=,eI=の両方に存在する
        -1: eI=のグラフにしか存在しない

節点出力データ)
節点ファイル1と節点ファイル2のいずれかに出現する節点について以下の値を出力する。
項目名: 内容
 ni    : ni=で指定したグラフにその節点があれば、そのファイル名
 nI    : nI=で指定したグラフにその節点があれば、そのファイル名
 diff : 差分の区分
         1: ni=のグラフにしか存在しない
         0: ni=,nI=の両方に存在する
        -1: nI=のグラフにしか存在しない


例)
$ cat g1.csv
node1,node2
a,b
b,c
c,d

$ cat g2.csv
node1,node2
b,a
c,d
d,e

$ mgdiff.rb ei=g1.csv eI=g2.csv ef=node1,node2
node1,node2,i,I,diff
a,b,g1.csv,g2.csv,0
b,c,g1.csv,,1
c,d,g1.csv,g2.csv,0
d,e,,g2.csv,-1

$ mgdiff.rb ei=g1.csv eI=g2.csv ef=node1,node2 -dir
node1,node2,i,I,diff
a,b,data/g1.csv,,1
b,a,,data/g2.csv,-1
b,c,data/g1.csv,,1
c,d,data/g1.csv,data/g2.csv,0
d,e,,data/g2.csv,-1

# Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
	$revision ="0" if $revision =~ /VERSION/
	STDERR.puts "version #{$version} revision #{$revision}"
	exit
end

help() if ARGV[0]=="--help" or ARGV.size <= 0
ver() if ARGV[0]=="--version"
args=MCMD::Margs.new(ARGV,"ei=,ef=,eI=,eF=,ni=,nf=,nI=,nF=,-dir,eo=,no=,T=","ei=,eI=,eo=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

ei = args.file("ei=","r")
eI = args.file("eI=","r")
ni = args.file("ni=","r")
nI = args.file("nI=","r")
eo = args.file("eo=","w")
no = args.file("no=","w")

if (ni and not nI) or (not ni and nI)
	raise("must specify both of ni= and nI=")
end

## ef=: cliqueファイルedge始点終了頂点項目名
ef1,ef2 = args.field("ef=", ei,"node1,node2",2,2)["names"]

## ev=: weights on input file
#ev = args.field("ev=", ei)
#ev = ev["names"].join(",") if ev

## eF=: 参照ファイルedge始点終了頂点項目名
eF = args.field("eF=", eI, nil, 2,2)
eF1,eF2=eF["names"] if eF
eF1=ef1 unless eF1
eF2=ef2 unless eF2

# ---- node field name on ni=
nf = args.field("nf=", ni, "node",1,1)
nf = nf["names"][0] if nf

## eF=: 参照ファイルedge始点終了頂点項目名
nF = args.field("nF=", nI, nil, 1,1)
nF = nF["names"] if nF
nF =nf unless eF

## eV=: weights on reference file
#eV = args.field("eV=", eI)
#eV = eV["names"].join(",") if eV
#eV=ev unless eV

# -dir: compare as a derected graph
dir=args.bool("-dir")

wf=MCMD::Mtemp.new
xxedge_i=wf.file
xxedge_I=wf.file

# ei=のサンプル
# id,node1,node2,size
# 0,e,f,2
# 1,b,f,2
# 2,a,c,4
# 2,a,d,4
# 2,a,e,4
# 2,c,d,4
# 2,c,e,4
# 2,d,e,4
# 3,a,b,4
# 3,a,c,4
# 3,a,d,4
# 3,b,c,4
# 3,b,d,4
# 3,c,d,4
#
# eI=のサンプル
# node1,node2
# a,b
# a,c
# a,d
# a,e
# b,c
# b,d
# b,f
# c,d
# c,e
# d,e
# e,f

# クリーニング(ei=)
f=""
f << "mcut   f=#{ef1},#{ef2} i=#{ei} |"
f << "mfsort f=#{ef1},#{ef2} |" unless dir
f << "msortf f=#{ef1},#{ef2} |"
f << "muniq  k=#{ef1},#{ef2} |"
f << "msetstr v=#{ei} a=ei o=#{xxedge_i}"
system(f)

# クリーニング(eI=)
f=""
f << "mcut   f=#{eF1}:#{ef1},#{eF2}:#{ef2} i=#{eI} |"
f << "mfsort f=#{ef1},#{ef2} |" unless dir
f << "msortf f=#{ef1},#{ef2} |"
f << "muniq  k=#{ef1},#{ef2} |"
f << "msetstr v=#{eI} a=eI o=#{xxedge_I}"
system(f)

f=""
f << "mjoin k=#{ef1},#{ef2} m=#{xxedge_I} f=eI i=#{xxedge_i} -n -N |"
f << "mcal  c='if(isnull($s{ei}),-1,if(isnull($s{eI}),1,0))' a=diff |"
f << "mcut  f=#{ef1},#{ef2},ei,eI,diff o=#{eo}"
system(f)

if ni and nI then
	xxnode_i=wf.file
	xxnode_I=wf.file

	# クリーニング(ni=)
	f=""
	f << "mcut   f=#{nf} i=#{ni} |"
	f << "msortf f=#{nf} |"
	f << "muniq  k=#{nf} |"
	f << "msetstr v=#{ni} a=ni o=#{xxnode_i}"
	system(f)

	# クリーニング(nI=)
	f=""
	f << "mcut   f=#{nF}:#{nf} i=#{nI} |"
	f << "msortf f=#{nf} |"
	f << "muniq  k=#{nf} |"
	f << "msetstr v=#{nI} a=nI o=#{xxnode_I}"
	system(f)

	f=""
	f << "mjoin k=#{nf} m=#{xxnode_I} f=nI i=#{xxnode_i} -n -N |"
	f << "mcal  c='if(isnull($s{ni}),-1,if(isnull($s{nI}),1,0))' a=diff |"
	f << "mcut  f=#{nf},ni,nI,diff o=#{no}"
	system(f)
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

