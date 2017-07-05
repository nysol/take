#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"
require "set"

# ver="1.0" # 初期リリース 2016/10/2
# ver="1.1" -pal,rank2=,-udout追加 2016/12/13
# ver="1.2" rank2=削除,-palの意味を変更 2016/12/25
$cmd=$0.sub(/.*\//,"")
$version="1.2"
$revision="###VERSION###"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) 相互類似関係にある枝を選択する。
内容) グラフG=(V,E)の任意の枝(a,b)∈E について条件b∈A and a∈Bを満たす枝を選択する。
      ここで、A(B)は節点a(b)の隣接節点の内、類似度が上位r個の節点集合のこと。
      rはrank=で指定し、類似度(項目)はsim=で指定する。
      結果は有向グラフとして出力される。例えば節点a,bが相互類似関係にあれば、a->b,b->aの両枝が出力される。
書式) #{$cmd} ei= [ef=] [ni=] [nf=] eo= [no=] [sim=] [dir=b|m|x] [-directed] [T=] [--help]

  ファイル名指定
  ei=   : 枝データファイル
  ef=   : 枝データ上の2つの節点項目名(省略時は"node1,node2")
  ni=   : 節点データファイル
  nf=   : 節点データ上の節点項目名(省略時は"node")
  eo=   : データ研磨後の枝データファイル
  no=   : データ研磨後の節点データファイル
  rank= : 類似度上位何個までの隣接節点を対象とするか(省略時は3)
  sim=  : rank=で使う節点間類似度(枝の重み)項目名。
  dir=  : b:双方向類似枝のみ出力する(デフォルト)
        : m:片方向類似枝のみ出力する
        : x:双方向類似枝、片方向類似枝両方共出力する。
  -directed: 有向グラフとみなして計算する。
  -udout: 無向グラフとして出力する。両方向に枝がある場合(a->b,b->a)の枝はa-bとして出力される。
          a->b,b->aで類似度が異なる場合は平均値が出力される。

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

例) 基本例
$ cat edge.csv
n1,n2,sim
a,b,0.40
a,c,0.31
a,d,0.31
b,c,0.20
b,d,0.24
b,e,0.14
c,d,0.30
d,e,0.09
$ #{$cmd} ei=edge.csv ef=n1,n2 sim=sim rank=2 eo=output.csv
#END# #{$cmd} ei=edge.csv ef=n1,n2 sim=sim rank=2 eo=output.csv; 2016/10/02 09:58:22
$ cat output.csv
n1%0,n2%1,sim
a,b,0.40
a,c,0.31
a,d,0.31
b,a,0.40
c,a,0.31
c,d,0.30
d,a,0.31
d,c,0.30

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

args=MCMD::Margs.new(ARGV,"ni=,nf=,ei=,ef=,eo=,no=,sim=,rank=,dir=,-directed,-udout","ei=,ef=,sim=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

ei = args. file("ei=","r") # edge file name
ni = args. file("ni=","r") # node file name

# ---- edge field names (two nodes) on ei=
ef1,ef2 = args.field("ef=", ei, nil,2,2)["names"]

# ---- node field name on ni=
nf = args.field("nf=", ni, nil,1,1)
nf = nf["names"][0] if nf

sim     = args.field("sim=",ei,nil,1,1)["names"][0]    # similarity measure
rank    = args.int("rank=",3)     # ranking 
dir     = args.str("dir=","b")    # 方向
directed= args.bool("-directed")  # directed graph
udout   = args.bool("-udout")     # 無向グラフ出力

unless ["b","m","x"].index(dir)
	MCMD::errorLog("dir= takes b, m, x")
	raise ArgumentError
end

eo      = args.file("eo=", "w")
no      = args.file("no=", "w")
logFile = args.file("log=", "w")

# ============
# entry point

wf=MCMD::Mtemp.new
xxpal   =wf.file
xxa=wf.file
xxb=wf.file
xxc=wf.file
xxd=wf.file
xxout=wf.file

# n1,n2,sim
# a,b,0.40
# a,c,0.31
# a,d,0.22
# b,c,0.20
# b,d,0.24
# b,e,0.14
# c,d,0.30
# d,e,0.09
if directed
	# 任意の枝a->bのaについて上位rankを選択
	f=""
	f << "mnumber k=#{ef1} s=#{sim}%nr e=skip S=1 a=##rank i=#{ei} |"
	f << "mselnum f=##rank c='[,#{rank}]' o=#{xxpal}"
	system(f)
else
	# 有向グラフにしてrankを計算
	system  "mfsort f=#{ef1},#{ef2} i=#{ei} o=#{xxa}"
	system  "mfsort f=#{ef2},#{ef1} i=#{ei} o=#{xxb}"
	f=""
	f << "mcat i=#{xxa},#{xxb} |"
	f << "muniq k=#{ef1},#{ef2} |"
	f << "mnumber k=#{ef1} s=#{sim}%nr e=skip S=1 a=##rank |"
	f << "mselnum f=##rank c='[,#{rank}]' o=#{xxpal}"
	system(f)
end

# 両方向+片方向
if dir=="x"
	f=""
	f << "mcut f=#{ef1},#{ef2},#{sim} i=#{xxpal} o=#{xxout}"
	system(f)

# 両方向
	elsif dir=="b"
	# 得られた上位rankグラフからa->b->cを作成し、a==cであれば相思相愛ということ
	f=""
	f << "mnjoin k=#{ef2} K=#{ef1} m=#{xxpal} f=#{ef2}:##ef2,#{sim}:sim2 i=#{xxpal} |"
	f << "msel c='$s{#{ef1}}==$s{##ef2}' |"
	f << "mcut f=#{ef1},#{ef2},#{sim} o=#{xxout}"
	system(f)

# 片方向
	else
	# 得られた上位rankグラフからa->b->cを作成し、a==cであれば相思相愛ということ
	f=""
	f << "mnjoin k=#{ef2} K=#{ef1} m=#{xxpal} f=#{ef2}:##ef2,#{sim}:sim2 i=#{xxpal} |"
	f << "msel c='$s{#{ef1}}==$s{##ef2}' |"
	f << "mcut f=#{ef1},#{ef2} o=#{xxc}"
	system(f)

	f=""
	f << "mcut f=#{ef1},#{ef2},#{sim} i=#{xxpal} |"
	f << "mcommon k=#{ef1},#{ef2} m=#{xxc} -r o=#{xxout}"
	system(f)
end

if udout
	f=""
	f << "mfsort f=#{ef1},#{ef2} i=#{xxout} |"
	f << "mavg   k=#{ef1},#{ef2} f=#{sim} |"
	f << "msortf f=#{ef1},#{ef2} o=#{eo}"
	system(f)
else
	system "msortf f=#{ef1},#{ef2} i=#{xxout} o=#{eo}"
end

if ni and no
	system "cp #{ni} #{no}"
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

