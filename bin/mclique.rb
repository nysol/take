#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"
require "nysol/take"

# ver="1.0" # 初期リリース 2014/2/20
# ver="1.1" # eo=,no=の機能追加 2014/3/27
# ver="1.2" # ni=,nf=の追加, eo=,no=の機能をmclique2g.rbに分離, 枝出力を廃止(-nodeによる出力のみ) 2014/8/2
$cmd=$0.sub(/.*\//,"")
$version="1.2"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) 一般グラフデータから極大クリークを列挙する。
書式) #{$cmd} ei= ef= [ni=] [nf=] [o=] [l=] [u=] [-node] [-all] [log=] [T=] [--help]

  ファイル名指定
  ei=    : 枝データファイル
  ef=    : 枝データ上の2つの節点項目名(省略時は"node1,node2")
  ni=    : 節点データファイル
  nf=    : 節点データ上の節点項目名(省略時は"node")
  o=     : 出力ファイル(クリークID-枝:-nodeを指定することでクリークID-節点に変更可能,省略時は標準出力)
  l=     : クリークを構成する最小節点数(ここで指定したサイズより小さいクリークは列挙されない)
  u=     : クリークを構成する最大節点数(ここで指定したサイズより大きいクリークは列挙されない)
  -all   : 極大クリークだけでなく、全クリークを列挙する。
  log=   : パラメータの設定値をkey-value形式のCSVで保存するファイル名

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力形式)
一般グラフを節点ペアで表現した形式。
他のいかなる節点とも接続のない節点は、サイズが１の自明なクリークであるため、入力対象外とする。

o=の出力形式)
クリークIDと接点を出力する。
出力項目は"id,node,size"の3項目である。
sizeはクリークを構成する節点数である。

備考)
内部で起動しているコマンドmaceは0から始まる整数で指定された節点名を前提として処理する。
一方で本コマンドは、任意の文字列で節点名を表したデータを処理できる。
それは、maceを実行する前に、それら文字列と整数との対応表を前処理で作成しているからである。

例)
$ cat data/edge.csv 
n1,n2
a,b
a,c
a,d
b,c
b,d
b,e
c,d
d,e

$ #{$cmd} ei=edge.csv ef=n1,n2 o=output.csv
#MSG# converting graph files into a pair of numbered nodes ...; 2014/01/06 14:27:17
#MSG# converting the numbered nodes into original name ...; 2014/01/06 14:27:17
#END# #{$cmd} ei=data/edge1.csv ef=n1,n2 -node o=output.csv; 2014/01/06 14:27:17
$ cat output.csv 
id,node,size
0,b,3
0,d,3
0,e,3
1,a,4
1,b,4
1,c,4
1,d,4

例) 節点ファイルも指定した例
$ cat edge.csv 
n1,n2
c,a
c,d
d,e
a,d
a,e

$ cat node.csv 
n
a
b
c
d
e
f

$ #{$cmd} ei=edge.csv ef=n1,n2 ni=node.csv nf=n o=output.csv
#MSG# converting graph files into a pair of numbered nodes ...; 2014/01/06 14:27:17
#MSG# converting the numbered nodes into original name ...; 2014/01/06 14:27:17
#END# #{$cmd} ei=data/edge1.csv ef=n1,n2 -node o=output.csv; 2014/01/06 14:27:17
$ cat output.csv 
id,node,size
0,b,1
1,a,3
1,d,3
1,e,3
2,a,3
2,c,3
2,d,3
3,f,1

# Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
	STDERR.puts "version #{$version}"
	exit
end

help() if ARGV.size <= 0 or ARGV[0]=="--help"
ver() if ARGV[0]=="--version"

args=MCMD::Margs.new(ARGV,"ei=,ef=,ni=,nf=,-all,o=,l=,u=,log=","ei=,ef=")

# コマンド実行可能確認
#CMD_mace="mace_20140215"
#exit(1) unless(MCMD::chkCmdExe(CMD_mace, "executable"))

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

all=args.bool("-all")

ei = args. file("ei=","r") # edgeファイル名
ni = args. file("ni=","r") # node file name

# ---- edge field names (two nodes) on ei=
ef1,ef2 = args.field("ef=", ei, "node1,node2",2,2)["names"]

# ---- node field name on ni=
nf = args.field("nf=", ni, "node",1,1)
nf = nf["names"][0] if nf

minSize = args.int("l=")    # クリークサイズ下限
maxSize = args.int("u=")    # クリークサイズ上限
oFile   = args.file("o=", "w")
logFile = args.file("log=", "w")

def g2pair(ni,nf,ei,ef1,ef2,ipair,mapFile)
	MCMD::msgLog("converting graph files into a pair of numbered nodes ...")
	wf=MCMD::Mtemp.new
	wf1=wf.file
	wf2=wf.file
	wf3=wf.file

	system "mcut f=#{ef1}:node i=#{ei} o=#{wf1}"
	system "mcut f=#{ef2}:node i=#{ei} o=#{wf2}"
	system "mcut f=#{nf}:node  i=#{ni} o=#{wf3}" if ni

	f=""
	if ni
		f << "mcat i=#{wf1},#{wf2},#{wf3} f=node |"
	else
		f << "mcat i=#{wf1},#{wf2}        f=node |"
	end
	f << "msortf f=node |"
	f << "muniq  k=node |"
	f << "mnumber s=node a=num  o=#{mapFile}"
	system(f)

	f=""
	f << "mcut f=#{ef1},#{ef2} i=#{ei} |"
	f << "msortf f=#{ef1} |"
	f << "mjoin  k=#{ef1} K=node m=#{mapFile} f=num:num1 |"
	f << "msortf f=#{ef2} |"
	f << "mjoin  k=#{ef2} K=node m=#{mapFile} f=num:num2 |"
	f << "mcut   f=num1,num2 |"
	f << "mfsort f=num1,num2 |"
	f << "msortf f=num1%n,num2%n -nfno o=#{ipair}"
	system(f)
end

# ============
# entry point
t=Time.now

# 入力ファイルをノード番号ペアデータ(input)に変換する。
# csvで指定された場合は、番号-アイテムmapデータも作成(xxmap)。
wf=MCMD::Mtemp.new
xxinp=wf.file
xxmap=wf.file
input=ei

g2pair(ni,nf,ei,ef1,ef2,xxinp,xxmap)
input=xxinp

xxmace = wf.file # maceの出力(tra形式)
xxpair = wf.file # 上記traをpair形式に変換したデータ

# mace実行
f="Me"
f="Ce" if all
f << " -l #{minSize}" if minSize
f << " -u #{maxSize}" if maxSize
#f << " -S #{maxOut}"  if maxOut
f << " #{input} #{xxmace}"
#system(f)
TAKE::run_mace(f)

MCMD::msgLog("converting the numbered nodes into original name ...")

id=0
fld="id,num,size"
MCMD::Mcsvout.new("o=#{xxpair} f=#{fld}"){|oCSV|
	# xxmace
	# 4 3 1
	# 3 2 1 0
	MCMD::Mcsvin.new("i=#{xxmace} -nfn"){|iCsv|
		iCsv.each{|flds|
			items=flds[0].split(" ")
			size=items.size
			(0...size).each{|i|
				# id-node形式による出力
				ar = []
				ar << id
				ar << items[i]
				ar << size
				oCSV.write(ar)
			}
			id+=1
		}
	}
}

# when ni= specified, it add the isolated single cliques.
if ni then
	xxcliq=wf.file
	xxiso =wf.file
	xxcat =wf.file

	f=""
	f << "msortf f=num  i=#{xxpair} |"
	f << "mselstr f=size v=1 |" if all # when -all specified
	f << "mcut f=num  |"
	f << "msortf f=num |"
	f << "muniq  k=num o=#{xxcliq}"
	system(f)

	# select all nodes which are not included in any cliques
	f=""
	f << "mcut   f=num i=#{xxmap} |"
	f << "msortf f=num |"
	f << "mcommon k=num m=#{xxcliq} -r |"
	f << "mnumber S=#{id} a=id -q|"
	f << "msetstr v=1 a=size |"
	f << "mcut f=id,num,size o=#{xxiso}"
	system(f)

	system "mcat i=#{xxpair},#{xxiso} o=#{xxcat}"
	system "cp #{xxcat} #{xxpair}"
end

w4=wf.file
system "msortf f=num i=#{xxmap} o=#{w4}"

# id-node形式による出力
f = ""
f << "msortf i=#{xxpair} f=num |"
f << "msortf f=num |"
f << "mjoin  m=#{w4} k=num f=node |"
f << "mcut   f=id,node,size |"
f << "msortf f=id,node o=#{oFile}"
system(f)

procTime=Time.now-t

# ログファイル出力
if logFile
	kv=args.getKeyValue()
	kv << ["time",procTime] 
	MCMD::Mcsvout.new("o=#{logFile} f=key,value"){|csv|
		kv.each{|line|
			csv.write(line)
		}
	}
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

