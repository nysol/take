#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"
require "nysol/take"
require "set"

# ver="1.0" # 初期リリース 2014/2/20
# ver="1.1" # 節点データ対応、途中経過出力 2014/8/1
# ver="1.2" # 出力nodeファイルの項目名をnf=の値にする 2016/11/11
$cmd=$0.sub(/.*\//,"")
$version="1.2"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) グラフデータの研磨をおこなう。
内容) 一般グラフデータを入力として、密度の高い部分グラフにあって枝が張られていないノードペアに枝を張る。
      逆に、密度の低い部分グラフにあって枝が張られているノードペアの枝を刈る。
      新たに張られる枝や刈られる枝の程度は、sim=とth=で与えた値によって変わる。
      詳細は以下に示したアルゴリズムを参照。
書式) #{$cmd} ei= [ef=] [ni=] [nf=] eo= [no=] [sim=i|I|s|S|T|R|P|C] th= [sup=] [-indirect] [iter=] [log=] [T=] [--help]

  ファイル名指定
  ei=    : 枝データファイル
  ef=    : 枝データ上の2つの節点項目名(省略時は"node1,node2")
  ni=    : 節点データファイル
  nf=    : 節点データ上の節点項目名(省略時は"node")
  eo=    : データ研磨後の枝データファイル
  no=    : データ研磨後の節点データファイル
  sim=   : 節点a,bと接続された枝集合を、それぞれA,Bとすると、節点a,bに枝を張るために用いる類似度。
           省略時はRが設定される。
             i: inclusion
             I: both-inclusion
             S: |A∩B|/max(|A|,|B|)
             s: |A∩B|/min(|A|,|B|)
             T (intersection): find pairs having common [threshld] items
             R (resemblance): find pairs s.t. |A\capB|/|A\cupB| >= [threshld]
             P (PMI): find pairs s.t. log (|A\capB|*|all| / (|A|*|B|)) >= [threshld]
             C (cosine distance): find pairs s.t. inner product of their normalized vectors >= [threshld]
  th=    : sim=で指定された類似度について、ここで指定された値以上の節点間に枝を張る。
  sup=   : 類似度計算において、|A∩B|>=supの条件を加える。省略すればsup=0。
  -indirect: 上記類似度計算における隣接節点集合から直接の関係を除外する。
             すなわち、A=A-b, B=B-a として類似度を計算する。
  iter=  : データ研磨の最大繰り返し数(デフォルト=30)
  log=   : パラメータの設定値や収束回数等をkey-value形式のCSVで保存するファイル名

  その他
  T= : ワークディレクトリ(default:/tmp)
  O=     : デバッグモード時、データ研磨過程のグラフを保存するディレクトリ名
  --help : ヘルプの表示

備考)
内部で起動しているコマンドsspcは0から始まる整数で指定された節点名を前提として処理する。
一方で本コマンドは、任意の文字列で節点名を表したデータを処理できる。
それは、sspcを実行する前に、それら文字列と整数との対応表を前処理で作成しているからである。

アルゴリズム)
  # 本コマンドでデフォルトで設定されている類似度関数。
  function sim(E,a,b,th,minSup)
    A=E上での節点aの隣接節点集合
    B=E上での節点bの隣接節点集合
		if |A ∩ B|>=minSup and |A ∩ B|/|A ∪ B|>=th
			return TRUE
		else
			return FALSE
		end
  end

  function conv(E,sim,th,minSup)
    foreach(e∈E)
      a,b=eを構成する2つの節点
      if sim(E,a,b,th,minSup)
        E' = E' ∪ edge(a,b)
      end
    end
    return E'
  end

  polishing(E,sim,th,minSup,iter)
    E:=グラフを構成する枝集合
    iter:=最大繰り返し回数
    sim:=類似度関数
    th:=最小類似度
    c=0
    while(c<iter)
      E'=conv(E,sim,th,minSup)
      if E==E'
        break
      end
      E=E'
      c=c+1
    end
    return E
  end

例) 枝データからのみグラフ研磨を実行する例
$ cat edge.csv
n1,n2
a,b
a,d
b,c
b,d
c,d
d,e
$ #{$cmd} ei=edge.csv ef=n1,n2 th=0.5 eo=output.csv
#MSG# converting graph files into a pair of numbered nodes ...; 2013/10/10 14:48:03
#MSG# polishing iteration #0; 2013/10/10 14:48:04
#MSG# converting the numbered nodes into original name ...; 2013/10/10 14:48:04
#END# #{$cmd} ei=edge.csv ef=n1,n2 th=0.1 eo=output.csv; 2013/10/10 14:48:04
$ cat output.csv
n1,n2
a,b
a,c
a,d
b,c
b,d
c,d

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

args=MCMD::Margs.new(ARGV,"ni=,nf=,ei=,ef=,-indirect,eo=,no=,th=,sim=,sup=,iter=,log=,O=","ei=,ef=,th=")

# コマンド実行可能確認
#CMD_sspc="sspc_20161209"
#CMD_grhfil="grhfil_20150920"
#exit(1) unless(MCMD::chkCmdExe(CMD_sspc  , "executable"))
#exit(1) unless(MCMD::chkCmdExe(CMD_grhfil, "executable"))

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

indirect=args.bool("-indirect")

ei = args. file("ei=","r") # edge file name
ni = args. file("ni=","r") # node file name

# ---- edge field names (two nodes) on ei=
ef1,ef2 = args.field("ef=", ei, "node1,node2",2,2)["names"]

# ---- node field name on ni=
nf = args.field("nf=", ni, "node",1,1)
nf = nf["names"][0] if nf

measure = args.str("sim=","R")    # similarity measure
minSupp = args.int("sup=",0)      # mimam support
iterMax = args.int("iter=",30,1)  # upper bound of iterations
th      = args.float("th=")       # threashold for similarity measure

eo      = args.file("eo=", "w")
no      = args.file("no=", "w")
logFile = args.file("log=", "w")
outDir  = args.str("O=")	# 過程出力
MCMD::mkDir(outDir) if outDir

# node数とedge数をカウント
def calGsize(file)
	nodes=Set.new
	edgeSize=0
	File.open(file,"r"){|fpr|
		while line = fpr.gets
			n1,n2 = line.split(" ")
			nodes << n1
			nodes << n2
			edgeSize+=1
		end
	}
	return nodes.size,edgeSize
end

# graphの各種特徴量を計算する
# orgNsizeが与えられなければ、node数は枝ファイル(file)から計算する。
# 0,1
# 0,2
# 0,3
# 1,2
# 1,3
def features(file,orgNsize=nil)
	nodes=Set.new
	graph=Hash.new
	edgeSize=0
	File.open(file,"r"){|fpr|
		while line = fpr.gets
			n1,n2 = line.split(" ")
			if n1>n2 then
				nt=n1; n1=n2; n2=nt
			end
			s=graph[n1]
			s << n2 if s and not s.include?(n2)
			nodes << n1
			nodes << n2
			edgeSize+=1
		end
	}

	# 密度
	dens=nil
	nSize=nodes.size.to_f
	dens=edgeSize.to_f/(nSize*(nSize-1.0)/2.0) if nSize>1.0

	# clustering coefficient
	graph.each{|s|
		size=s.size
	}

	nodeSize,edgeSize=calGsize(file)

	nSize=nodeSize.to_f
	nSize=orgNsize.to_f if orgNsize

	dens=nil
	dens=edgeSize.to_f/(nSize*(nSize-1)/2.0) if nSize>1

	return nSize,edgeSize,dens
end

def same?(file1,file2)
  xx=MCMD::Mtemp.new.file

	return false if File.size(file1)!=File.size(file2)
	system "diff -q #{file1} #{file2} > #{xx}"
	return false if File.size(xx)!=0
	return true
end

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
	f << "mnumber -q a=num o=#{mapFile}"
	system(f)

	f=""
	f << "mcut f=#{ef1},#{ef2} i=#{ei} |"
	f << "msortf f=#{ef1} |"
	f << "mjoin  k=#{ef1} K=node m=#{mapFile} f=num:num1 |"
	f << "msortf f=#{ef2} |"
	f << "mjoin  k=#{ef2} K=node m=#{mapFile} f=num:num2 |"
	f << "mcut   f=num1,num2 |"
	f << "mfsort f=num1,num2 |"
	f << "msortf f=num1%n,num2%n -nfno |"
	f << "tr ',' ' ' >#{ipair}"
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
xxmaprev=wf.file
input=ei

g2pair(ni,nf,ei,ef1,ef2,xxinp,xxmap)
input=xxinp
system "msortf f=num i=#{xxmap} o=#{xxmaprev}"

xxpair = wf.file # sscpの出力(pair形式)
xxtra  = wf.file # sscpの入力(tra形式)
xxprev = wf.file # 前回のxxtra
system "cp #{input} #{xxpair}"

nSizes=[]
eSizes=[]
denses=[]

iter=0
while true
	# グラフ特徴量の計算
	if logFile
		nSize,eSize,dens=features(xxpair)
		nSizes << nSize
		eSizes << eSize
		denses << dens
	end

	# node pairをsspc入力形式に変換
	if indirect then
		#system "#{CMD_grhfil} ue  #{xxpair} #{xxtra}"
		TAKE::run_grhfil("ue #{xxpair} #{xxtra}")

	else
		#system "#{CMD_grhfil} ue0 #{xxpair} #{xxtra}"
		TAKE::run_grhfil("ue0 #{xxpair} #{xxtra}")
	end

	
	# outDirが指定されていれば、途中経過グラフを出力
	if outDir then
		f=""
		f << "tr     ' ' ',' <#{xxpair} |"
		f << "mcut   f=0:num1,1:num2 -nfni |"
		f << "msortf f=num1 |"
		f << "mjoin  k=num1 K=num m=#{xxmaprev} f=node:#{ef1} |"
		f << "msortf f=num2 |"
		f << "mjoin  k=num2 K=num m=#{xxmaprev} f=node:#{ef2} |"
		f << "mcut   f=#{ef1},#{ef2} |"
		f << "mfsort f=#{ef1},#{ef2} |"
		f << "msortf f=#{ef1},#{ef2} o=#{outDir}/pair_#{iter}.csv"
		system(f)
	end

	# 終了判定
	break if iter>=iterMax
	break if iter!=0 and same?(xxtra,xxprev)

	MCMD::msgLog("polishing iteration ##{iter} (tra size=#{File.size(xxtra)}")
	system "cp #{xxtra} #{xxprev}"
	puts "sspc #{measure} -l #{minSupp} #{xxtra} #{th} #{xxpair}"
	#system "#{CMD_sspc} #{measure} -l #{minSupp} #{xxtra} #{th} #{xxpair}"
	TAKE::run_sspc("#{measure} -l #{minSupp} #{xxtra} #{th} #{xxpair}")


	iter+=1
end

# 上記iterationで収束したマイクロクラスタグラフを元の節点文字列に直して出力する
MCMD::msgLog("converting the numbered nodes into original name ...")
f=""
f << "tr     ' ' ',' <#{xxpair} |"
f << "mcut   f=0:num1,1:num2 -nfni |"
f << "msortf f=num1 |"
f << "mjoin  k=num1 K=num m=#{xxmaprev} f=node:#{ef1} |"
f << "msortf f=num2 |"
f << "mjoin  k=num2 K=num m=#{xxmaprev} f=node:#{ef2} |"
f << "mcut   f=#{ef1},#{ef2} |"
f << "mfsort f=#{ef1},#{ef2} |"
f << "msortf f=#{ef1},#{ef2} o=#{eo}"
system(f)

if no then
	f=""
	if nf
		f << "mcut f=node:#{nf} i=#{xxmap} o=#{no}"
	else
		f << "mcut f=node i=#{xxmap} o=#{no}"
	end
	system(f)
end

procTime=Time.now-t

# ログファイル出力
if logFile
	kv=args.getKeyValue()
	kv << ["iter",iter] 
	kv << ["time",procTime] 
	(0...nSizes.size).each{|i|
		kv << ["nSize#{i}",nSizes[i]]
		kv << ["eSize#{i}",eSizes[i]]
		kv << ["dens#{i}" ,denses[i]]
	}
	MCMD::Mcsvout.new("o=#{logFile} f=key,value"){|csv|
		kv.each{|line|
			csv.write(line)
		}
	}
end

# 終了メッセージ
MCMD::endLog(args.cmdline)
