#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"
require "nysol/take"
require "set"

# ver="1.0" # 初期リリース              2015/09/27
# ver="1.1" # 2つ目の類似度と閾値の追加 2015/11/22
# ver="1.2" # logファイル出力追加       2016/06/25
# ver="1.3" # kn=を追加                 2016/08/24
# ver="1.4" # kn2=を追加                2016/09/10
$cmd=$0.sub(/.*\//,"")
$version="1.4"
$revision="###VERSION###"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) 2部グラフの研磨をおこなう。
内容) 2部グラフを入力として、密度の高い2部部分グラフにあって枝が張られていないノードペアに枝を張る。
      逆に、密度の低い2部部分グラフにあって枝が張られているノードペアの枝を刈る。
      新たに張られる枝や刈られる枝の程度は、sim=,th=とsim2,th2で与えた値によって変わる。
書式) #{$cmd} ei= [ef=] [nf=] eo= [sim=i|I|s|S|T|R|P|C] th= [th2=] [sim2=i|I|s|S|T|R|P|C] [sup=] [iter=] [log=] [T=] [--help]

  ファイル名指定
  ei=    : 枝データファイル
  ef=    : 枝データ上の2つの節点項目名(省略時は"node1,node2")
  eo=    : データ研磨後の枝データファイル
  sim|2= : 節点a,bと接続された枝集合を、それぞれA,Bとすると、節点a,bに枝を張るために用いる類似度。
           省略時はRが設定される。(sim2のデフォルト:sim=)
             i: inclusion
             I: both-inclusion
             S: |A∩B|/max(|A|,|B|)
             s: |A∩B|/min(|A|,|B|)
             T (intersection): find pairs having common [threshld] items
             R (resemblance): find pairs s.t. |A\capB|/|A\cupB| >= [threshld]
             P (PMI): find pairs s.t. log (|A\capB|*|all| / (|A|*|B|)) >= [threshld]
             C (cosine distance): find pairs s.t. inner product of their normalized vectors >= [threshld]
  th|2=  : sim|2=で指定された類似度について、ここで指定された値以上の節点間に枝を張る。(th2のデフォルト:th=)
  sup=   : 左の部の次数がsup以上のノードを対象とする。省略すればsup=0。
  kn|2 = : kn=で指定された値以上の共起頻度を対象とする。kn2=で指定された値以上の次数を持つ右部を対象とする。
           省略すればkn=1,kn2=1 [1以上の整数]
  iter=  : データ研磨の最大繰り返し数(デフォルト=30)
  log=   : ディレクトリ内にパラメータの設定値や収束回数等をkey-value形式のCSVで出力.繰り返し毎に生成される類似グループ出力


  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

備考)
内部で起動しているコマンドsspcは0から始まる整数で指定された節点名を前提として処理する。
一方で本コマンドは、任意の文字列で節点名を表したデータを処理できる。
それは、sspcを実行する前に、それら文字列と整数との対応表を前処理で作成しているからである。

例) 2部グラフデータからのみグラフ研磨を実行する例
$ cat edge.csv
node1,node2
A,a
A,b
B,a
B,b
C,c
C,d
D,b
D,e

$ #{$cmd} ei=edge.csv ef=n1,n2 th=0.2 eo=output.csv
#MSG# converting the numbered nodes into original name ...; 2015/09/27 21:59:08
#END# #{$cmd} ei=edge.csv ef=n1,n2 th=0.2 eo=output.csv; 2015/09/27 21:59:08
$ cat output.csv
n1,n2
A,a
A,b
A,e
B,a
B,b
B,e
C,c
C,d
D,a
D,b
D,e

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

args=MCMD::Margs.new(ARGV,"ei=,ef=,eo=,th=,sim=,th2=,sim2=,kn=,kn2=,sup=,iter=,log=","ei=,ef=,th=")

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


ei = args. file("ei=","r") # edge file name

# ---- edge field names (two nodes) on ei=
$ef1,$ef2 = args.field("ef=", ei, "node1,node2",2,2)["names"]

measure  = args.str("sim=","R")        # similarity measure
measure2 = args.str("sim2=",measure)   # similarity measure
minSupp  = args.int("sup=",0)          # minimam support
iterMax  = args.int("iter=",30,1)      # upper bound of iterations
th       = args.float("th=")           # threashold for similarity measure
th2      = args.float("th2=",th)       # threashold for similarity measure
kn       = args.float("kn=",1)         # no. of interaction size more than threshold 
kn2      = args.float("kn2=",1)         # no. of right node size more than threshold 

eo      = args.file("eo=", "w")
logDir  = args.file("log=", "w")
outDir  = args.str("O=")	# 過程出力
MCMD::mkDir(outDir) if outDir
MCMD::mkDir(logDir) if logDir

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

def same?(file1,file2)
  xx=MCMD::Mtemp.new.file

	return false if File.size(file1)!=File.size(file2)
	system "diff -q #{file1} #{file2} > #{xx}"
	return false if File.size(xx)!=0
	return true
end

def edge2mtx(ei,itra)
	MCMD::msgLog("converting graph files into a pair of numbered nodes ...")
	wf=MCMD::Mtemp.new
	wf1=wf.file
	wf2=wf.file
	wf3=wf.file


	system "mcut f=#{$ef1}:node i=#{ei} o=#{wf1}"
	system "mcut f=#{$ef2}:node i=#{ei} o=#{wf2}"

	# 各部ごとにマッピングテーブルを用意
	system "mcut f=#{$ef1} i=#{ei} |muniq k=#{$ef1} |mdelnull f=#{$ef1} |mnumber -q a=num1 S=1 o=#{PART1}"
	system "mcut f=#{$ef2} i=#{ei} |muniq k=#{$ef2} |mdelnull f=#{$ef2} |mnumber -q a=num2 S=1 o=#{PART2}"

	f=""
	f << "mcut f=#{$ef1},#{$ef2} i=#{ei} |"
	f << "msortf f=#{$ef1} |"
	f << "mjoin  k=#{$ef1} m=#{PART1} f=num1 |"
	f << "msortf f=#{$ef2} |"
	f << "mjoin  k=#{$ef2} m=#{PART2} f=num2 |"
	f << "mcut   f=num1,num2 |"
	f << "mtra   k=num1 f=num2 |"
	f << "msortf f=num1%n      |"
	f << "mcut f=num2 -nfno  |"
	f << "tr ',' ' ' >#{itra}"
	system(f)

end

def noPat
		MCMD::msgLog("There is no frequent item. The value is too large")
		exit 
end

def convRsl(ifile,ofile,logDir=nil)

	# 上記iterationで収束したマイクロクラスタグラフを元の節点文字列に直して出力する
	MCMD::msgLog("converting the numbered nodes into original name ...")
	f=""
	f << "mcut -nfni f=0:tra <#{ifile} |"
	f << "msed f=tra c=' $' v="" |"
	f << "mnumber -q S=1 a=num1 |"
	f << "mtra -r f=tra:num2 |"
	f << "mjoin  k=num2 m=#{PART2} f=#{$ef2} |"
	f << "mjoin  k=num1 m=#{PART1} f=#{$ef1} |"
	f << "msortf f=num1%n,num2%n |"
	f << "mcut f=#{$ef1},#{$ef2} |"
	if logDir
	f << "mfldname -q o=#{logDir}/#{ofile}" 
	else
	f << "mfldname -q o=#{ofile}"
	end
	system(f)

end

def convSim(ifile,ofile,logDir)

	f=""
	f << "mcut -nfni f=0:tra <#{ifile} |"
	f << "msed f=tra c=' $' v="" |"
	f << "mnumber -q S=1 a=num0 |"
	f << "mtra -r f=tra:num11 |"
	f << "mnumber -q S=1 a=order |"
	f << "mcal c='${num11}+1' a=num1 |"
	f << "mjoin  k=num1 m=#{PART1} f=#{$ef1} |"
	f << "msortf f=order%n,num1%n |"
	f << "mtra k=num0 s=order f=#{$ef1} |"
	f << "mcut f=#{$ef1} o=#{logDir}/#{ofile}"
	system(f)

end

# ============
# entry point
t=Time.now

# 入力ファイルをノード番号ペアデータ(input)に変換する。
# csvで指定された場合は、番号-アイテムmapデータも作成
wf=MCMD::Mtemp.new
xxinp=wf.file
PART1=wf.file  # 数値と文字のマッピング用1
PART2=wf.file  # 数値と文字のマッピング用1

edge2mtx(ei,xxinp)
input=xxinp

xxpair = wf.file # pair形式
xxtra  = wf.file # tra形式
xxitra = wf.file # 処理入力のtra形式
xxdiff = wf.file # 差分ファイル
xxprev = wf.file # 前回のxxtra
xxsimgp= wf.file # 類似度グループの保存

nSizes=[]
eSizes=[]
denses=[]

#system "#{CMD_grhfil} D"" #{input} #{xxitra}"
TAKE::run_grhfil("D"" #{input} #{xxitra}")
puts   "grhfil D"" #{input} #{xxitra}"


iter=0
while true

	# 終了判定
	break if iter>=iterMax
	break if iter!=0 and same?(xxitra,xxprev)

	MCMD::msgLog("polishing iteration ##{iter} (tra size=#{File.size(xxitra)}")
	system "cp #{xxitra} #{xxprev}"

	nodeSize,edgeSize=calGsize(xxitra)
	edgeSize1 = edgeSize+1

	#system "#{CMD_sspc} t#{measure} -T #{kn} -l #{minSupp} -U 100000 -L 1 #{xxitra} #{th} #{xxpair}"
	TAKE::run_sspc("t#{measure} -T #{kn} -l #{minSupp} -U 100000 -L 1 #{xxitra} #{th} #{xxpair}")
	puts   "sspc t#{measure} -T #{kn} -l #{minSupp} -U 100000 -L 1 #{xxitra} #{th} #{xxpair}"

	# 閾値が大きくてパターンが抽出されない場合は終了
	noPat unless File.exist?("#{xxpair}")
	noPat if File.size("#{xxpair}") == 0

	# node pairをsspc入力形式に変換
	# ./grhfil/grhfil eu0_ _TMP2_ _TMP3_
	#system "#{CMD_grhfil} eu0 #{xxpair} #{xxtra}"
	TAKE::run_grhfil("eu0 #{xxpair} #{xxtra}")
	puts "grhfil eu0 #{xxpair} #{xxtra}"

	convSim("#{xxtra}","simGp#{iter}.csv",logDir) if logDir

	# 入力と類似行列を連結
	system "cat #{xxitra} #{xxtra} > #{xxpair}"

  # 入力ファイルと、比較ファイルを比較 ＝＞ 新しいトランザクションDBの完成
	#system "#{CMD_sspc} #{measure2} -T #{kn2} -c #{edgeSize} #{xxpair} #{th2} #{xxtra}"
	TAKE::run_sspc("#{measure2} -T #{kn2} -c #{edgeSize} #{xxpair} #{th2} #{xxtra}")
	puts   "sspc #{measure2} -T #{kn2} -c #{edgeSize} #{xxpair} #{th2} #{xxtra}"


	# 閾値が大きくてパターンが抽出されない場合は終了
	noPat unless File.exist?("#{xxtra}")
	noPat if File.size("#{xxtra}") == 0

  # 行列形式に変換
	#system "#{CMD_grhfil} ed #{xxtra} #{xxpair}"
	TAKE::run_grhfil("ed #{xxtra} #{xxpair}")
	puts   "grhfil ed #{xxtra} #{xxpair}"

	# catした入力ファイルを削除"
	system "tail -n +#{edgeSize1} #{xxpair} >#{xxtra}"
	#system "#{CMD_grhfil} D #{xxtra} #{xxpair}"
	TAKE::run_grhfil("D #{xxtra} #{xxpair}")
	puts   "grhfil D #{xxtra} #{xxpair}"

	x="$d2/grhfil dE -d _TMP_ _TMP8_ _TMP9_"  # 差分計算
	#system "#{CMD_grhfil} dE -d #{xxitra} #{xxpair} #{xxdiff}"
	TAKE::run_grhfil("dE -d #{xxitra} #{xxpair} #{xxdiff}")
	puts   "grhfil dE -d #{xxitra} #{xxpair} #{xxdiff}"


	system "cp #{xxpair} #{xxitra}"
	if logDir
		#system "#{CMD_grhfil} D #{xxitra} #{xxpair}"
		TAKE::run_grhfil("D #{xxitra} #{xxpair}")
		puts   "grhfil D #{xxitra} #{xxpair}"
		convRsl(xxpair,"iter#{iter}.csv",logDir) if logDir
	end
	iter+=1

end

#system "#{CMD_grhfil} D #{xxitra} #{xxpair}"
TAKE::run_grhfil("D #{xxitra} #{xxpair}")
puts   "grhfil D #{xxitra} #{xxpair}"
convRsl("#{xxpair}",eo)


procTime=Time.now-t

# ログファイル出力
if logDir
	kv=args.getKeyValue()
	kv << ["iter",iter] 
	kv << ["time",procTime] 
	(0...nSizes.size).each{|i|
		kv << ["nSize#{i}",nSizes[i]]
		kv << ["eSize#{i}",eSizes[i]]
		kv << ["dens#{i}" ,denses[i]]
	}
	MCMD::Mcsvout.new("o=#{logDir}/keyVal.csv f=key,value"){|csv|
		kv.each{|line|
			csv.write(line)
		}
	}
end

# 終了メッセージ
MCMD::endLog(args.cmdline)
