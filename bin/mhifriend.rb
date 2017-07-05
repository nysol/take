#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# 1.0 initial development: 2016/12/26
$cmd=$0.sub(/.*\//,"")
$version="1.0"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) hierarchical friend: トランザクションデータにfriendによるpolishを階層的に適用する。

書式) #{$cmd} i= tid= item= [class=] [no=] eo= s=|S= [-node_support] [rank=] [sim=] [maxLevel=] [T=] [--help]
  i=     : トランザクションデータファイル【必須】
  tid=   : トランザクションID項目名【必須】
  item=  : アイテム項目名【必須】
  no=    : 出力ファイル(節点)
  eo=    : 出力ファイル(辺:節点ペア)
  s=     : 最小支持度(全トランザクション数に対する割合による指定): 0以上1以下の実数
  S=     : 最小支持度(トランザクション数による指定): 1以上の整数
  -node_support : 節点にもs=,S=の条件を適用する。指定しなければ全てのitemを節点として出力する。
  以上のパラメータ mtra2gc.rbのパラメータであり、詳細は同コマンドヘルプを参照のこと。

  rank=  : 枝を張る条件で、双方向類似枝の上位何個までを選択するか(デフォルト:3)
  sim=   : rank=で利用する類似度を指定する。(デフォルト:S)
           指定できる類似度は以下の3つのいずれか一つ。
             S:Support, J: Jaccard, P:normalized PMI, C:Confidence

  maxLevel= : 階層化の回数上限(デフォルト:0,収束するまで)


  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力ファイル形式)
トランザクションIDとアイテムの２項目によるトランザクションデータ。

o=の出力形式)
枝ファイル: cluster,node,support,frequency,total
節点ファイル: cluster%0,node1%1,node2%2,support(sim=で指定した類似度)

例)
$ cat tra1.csv
id,item
1,a
1,b
1,d
1,e
2,a
2,b
2,e
3,a
3,d
3,e
6,b
6,d
7,d
7,e
4,c
4,f
4,b
5,c
5,f
5,e
8,g
8,h
9,g
9,h
0,i
a,j
a,c
a,a

$ #{$cmd}hifriend.rb i=tra1.csv no=node1.csv eo=edge1.csv tid=id item=item sim=S S=2 rank=3
$ cat edge.csv 
cluster%0,node1%1,node2%2,support
#1_1,a,b,0.1818181818
#1_1,a,d,0.1818181818
#1_1,a,e,0.2727272727
#1_1,b,d,0.1818181818
#1_1,b,e,0.1818181818
#1_1,d,e,0.2727272727
#1_2,c,f,0.1818181818
#1_3,g,h,0.1818181818
#2_1,#1_1,#1_2,0.2727272727

$ cat node.csv
cluster%0,node%1,support,frequency,total
,i,0.09090909091,1,11
,j,0.09090909091,1,11
#1_1,a,0.3636363636,4,11
#1_1,b,0.3636363636,4,11
#1_1,d,0.3636363636,4,11
#1_1,e,0.4545454545,5,11
#1_2,c,0.2727272727,3,11
#1_2,f,0.1818181818,2,11
#1_3,g,0.1818181818,2,11
#1_3,h,0.1818181818,2,11
#2_1,#1_1,0.7272727273,8,11
#2_1,#1_2,0.2727272727,3,11

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

args=MCMD::Margs.new(ARGV,"i=,tid=,item=,no=,eo=,s=,S=,-node_support,rank=,sim=,maxLevel=,-num,-verbose","i=,tid=,item=,eo=,no=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end
traFile= args.str("i=")
idFN   = args.str("tid=")
itemFN = args.str("item=")
numtp  = args.bool("-num")

onFile  = args. file("no=", "w")
oeFile  = args. file("eo=", "w")

# mtra2gc parameters
sp1    = args.str("s=")
sp2    = args.str("S=")
node_support=args.bool("-node_support")

# firend parameters
sim = args.str("sim=")
if    sim=="S"
	simStr="support"
elsif sim=="J"
	simStr="jaccard"
elsif sim=="P"
	simStr="PMI"
elsif sim=="C"
	simStr="confidence"
else
	MCMD::errorLog("sim= takes S, J, P or C")
	raise ArgumentError
end
rank = args.str("rank=")     # ranking 

maxLevel = args.int("maxLevel=",0)     # ranking 


# traファイルから類似度グラフを作成
def runTra2gc(traFile,paramTra2gc,onFile,oeFile)
	### mtra2gc.rb
	system "mtra2gc.rb #{paramTra2gc} i=#{traFile} no=#{onFile} eo=#{oeFile}"
	# node1%0,node2%1,support,frequency,frequency1,frequency2,total,lift,jaccard,PMI
	# a,b,0.1818181818,2,4,4,11,1.375,0.3333333333,0.1868039815
	# a,d,0.1818181818,2,4,4,11,1.375,0.3333333333,0.1868039815
	# a,e,0.2727272727,3,4,5,11,1.65,0.5,0.385424341
	# b,d,0.1818181818,2,4,4,11,1.375,0.3333333333,0.1868039815
	# b,e,0.1818181818,2,4,5,11,1.1,0.2857142857,0.05590865902
	# c,f,0.1818181818,2,3,2,11,3.6667,0.6666666667,0.7621554117
	# d,e,0.2727272727,3,4,5,11,1.65,0.5,0.385424341
	# g,h,0.1818181818,2,2,2,11,5.5,1,1
end

def runPolish(simgN,simgE,paramPolish,polishN,polishE)
	## mpolishs.rb
	system "mfriends.rb -udout -directed ef=node1,node2 nf=node #{paramPolish} ni=#{simgN} ei=#{simgE} eo=#{polishE} no=#{polishN}"
	# polishE
	# node1%0,node2%1,jaccard
	# a,b,0.3333333333
	# a,d,0.3333333333
	# a,e,0.5
	# b,d,0.3333333333
	# b,e,0.2857142857
	# c,f,0.6666666667
	# d,e,0.5
	# g,h,1
end

def runClustering(niFile,eiFile,paramCluster,oFile)
	### mccomp.rb
	system "mccomp.rb nf=node ef=node1,node2 #{paramCluster} ni=#{niFile} ei=#{eiFile} o=#{oFile}"
	# id%0,node,size
	# 1,a,4
	# 1,b,4
	# 1,d,4
	# 1,e,4
	# 2,c,2
	# 2,f,2
	# 3,g,2
	# 3,h,2
	# 4,i,1
	# 5,j,1
end

def runConvert(traFile,idFN,itemFN,level,clusterFile,mFile,oFile,maxNo)
	temp=MCMD::Mtemp.new
	xxfreq=temp.file
	xxmf0 =temp.file
	xxmf1 =temp.file
	xxmf2 =temp.file
	if maxNo then
		# node-clusterマスター作成
		# (1つのクラスタに1つのnodeはオリジナルアイテムをclusterに)
		system "mcount k=id a=freq i=#{clusterFile} o=#{xxfreq}"
		f=""
		f << "mjoin k=id m=#{xxfreq} f=freq i=#{clusterFile} |"
		f << "mselnum c='(1,]' f=freq u=#{xxmf0} |"
		f << "mnumber k=id -B S=1 a=num |"
		f << "mcal c='${num}+#{maxNo}' a=cluster o=#{xxmf1};"
		f << "mcal c='$s{node}' a=cluster i=#{xxmf0} o=#{xxmf2};"
		f << "mcat f=node,freq,cluster i=#{xxmf1},#{xxmf2} o=#{mFile}"
		system(f)
		f= ""
		f << "mstats c=max f=cluster i=#{xxmf1}|"
		f << "mcut f=cluster -nfno "
		maxNo = `#{f}`.chomp.to_i
	else

		# node-clusterマスター作成
		# (1つのクラスタに1つのnodeはオリジナルアイテムをclusterに)
		system "mcount k=id a=freq i=#{clusterFile} o=#{xxfreq}"
		f=""
		f << "mjoin k=id m=#{xxfreq} f=freq i=#{clusterFile} |"
		f << "mcal c='if(${freq}==1,$s{node},\"##{level}_\"+$s{id})' a=cluster o=#{mFile}"
		system(f)
	end

	# トランザクションのitemをclusterに変換
	f=""
	f << "mjoin k=#{itemFN} K=node m=#{mFile} f=cluster i=#{traFile} -n |"
	f << "mcal c='if(isnull($s{cluster}),$s{#{itemFN}},$s{cluster})' a=newItem |"
	f << "mcut f=#{itemFN},cluster -r |"
	f << "mfldname f=newItem:#{itemFN} |"
	f << "muniq k=#{idFN},#{itemFN}  o=#{oFile}"
	system(f)
	return maxNo
end

def runSaveNode(polishN,simgN,ncMap,oFile)
	# save to his
	# node情報
	f=""
	f << "mcut f=node i=#{polishN} |"
	f << "mjoin k=node m=#{ncMap} f=cluster |"
	f << "mjoin k=node m=#{simgN} f=support,frequency,total o=#{oFile}"
	system(f)
end

def runSaveEdge(polishE,simgE,ncMap,simStr,oFile)
	f=""
	f << "mcut f=node1,node2,#{simStr} i=#{polishE} |"
	f << "mjoin k=node1 K=node m=#{ncMap} f=cluster |"
	f << "mcut f=node1,node2,cluster,#{simStr} o=#{oFile}"
	system(f)
end

##########################################
# iFileのitemFN項目のitem番号最大値を取得
def getMaxNo(iFile,itemFN)
	maxNo = 0;
	f= ""
	f << "mstats c=max f=#{itemFN} i=#{iFile} |"
	f << "mcut f=#{itemFN} -nfno "
	maxNo = `#{f}`.chomp.to_i
	return maxNo
end

def outputNode(iPath,lastItemNo,oFile)
	temp=MCMD::Mtemp.new
	xxwk1=temp.file
	xxwk2=temp.file
	# ノードファイルの出力
	# いずれのレベルにおいても孤立ノードのクラスタ行は削除する
	# 条件: node==cluster and (nodeが他の行のnodeとして出現していない or nodeはクラスタ)
	# node%0,support,frequency,total,cluster
	# #1_1,0.7272727273,8,11,#2_1
	# #1_2,0.2727272727,3,11,#2_1
	# #1_3,0.1818181818,2,11,#1_3
	# i,0.09090909091,1,11,i
	# j,0.09090909091,1,11,j
	f=""
	f << "mcat i=#{iPath}/node* |"
	f << "muniq k=cluster,node o=#{xxwk1}"
	system(f)
	system "mcut f=node i=#{xxwk1} | mcount k=node a=freq o=#{xxwk2}"
	f=""
	f << "mjoin k=node m=#{xxwk2} i=#{xxwk1} |"
	if lastItemNo then
		f << "msel c='$s{node}==$s{cluster} && (${freq}>1 || ${node}>#{lastItemNo})' -r |"
	else
		f << "msel c='$s{node}==$s{cluster} && (${freq}>1 || left($s{node},1)==\"#\")' -r |"
	end
	f << "mcal c='if($s{node}==$s{cluster},\"\",$s{cluster})' a=newClust|"
	f << "mcut f=newClust:cluster,node,support,frequency,total |"
	f << "msortf f=cluster,node o=#{oFile}"
	system(f)
end

def outputEdge(iPath,simStr,oFile)
	# エッジファイルの出力
	# node1%0,node2%1,jaccard,cluster
	# a,b,0.3333333333,#1_1
	# a,d,0.3333333333,#1_1
	# a,e,0.5,#1_1
	f=""
	f << "mcat i=#{iPath}/edge* |"
	f << "mcut f=cluster,node1,node2,#{simStr} |"
	f << "msortf f=cluster,node1,node2 o=#{oFile}"
	system(f)
end

def hiPolish(traFile,idFN,itemFN,simStr,paramTra2gc,paramPolish,paramCluster,maxLevel,oPath,maxNo)
	temp=MCMD::Mtemp.new
	xxtra  =temp.file
	xxtra2 =temp.file
	xxsimgN=temp.file
	xxsimgE=temp.file
	xxpolishN=temp.file
	xxpolishE=temp.file
	xxcluster=temp.file
	xxncMap=temp.file

	system "cp #{traFile} #{xxtra}"
	counter=1
	while true
		# 繰り返し上限の判定
		break if maxLevel!=0 and counter>maxLevel

		# 類似度グラフの作成
		runTra2gc(xxtra,paramTra2gc,xxsimgN,xxsimgE)
		# system "head #{xxsimgE}"
		# system "cat #{xxsimgE}"
		# node1%0,node2%1,frequency,frequency1,frequency2,total,support,confidence,lift,jaccard,PMI
		# a,b,2,4,4,11,0.1818181818,0.5,1.375,0.3333333333,0.1868039815
		# a,d,2,4,4,11,0.1818181818,0.5,1.375,0.3333333333,0.1868039815

		# polish実行
		runPolish(xxsimgN,xxsimgE,paramPolish,xxpolishN,xxpolishE)
		#system "head #{xxpolishE}"
		# node1%0,node2%1,support
		# a,b,0.1818181818
		# a,d,0.1818181818
		# a,e,0.2727272727

		# stop条件
		size=MCMD::mrecount("i=#{xxpolishE}")
		break if size==0

		# クラスタリング(連結成分など)
		runClustering(xxpolishN,xxpolishE,paramCluster,xxcluster)
		# system "head #{xxcluster}"
		# id%0,node,size
		# 1,a,4
		# 1,b,4
		# 1,d,4
		# 1,e,4
		# 2,c,2
		# 2,f,2

		# traのitemをクラスタitemに変換
		maxNo=runConvert(xxtra,idFN,itemFN,counter,xxcluster,xxncMap,xxtra2,maxNo)
		# system "head #{xxncMap}"
		# id%0,node,size,freq,cluster
		# 1,a,4,4,#1_1
		# 1,b,4,4,#1_1
		# 1,d,4,4,#1_1
		# 1,e,4,4,#1_1
		# 2,c,2,2,#1_2
		# 2,f,2,2,#1_2
		# system "head #{xxtra2}"
		# system "cat #{xxtra2}"
		# id%0,item%1
		# 0,i
		# 1,#1_1
		# 2,#1_1
		# 3,#1_1
		#

		# node,edgeの保存
		runSaveNode(xxpolishN,xxsimgN,xxncMap       ,"#{oPath}/node_#{counter}")
		runSaveEdge(xxpolishE,xxsimgE,xxncMap,simStr,"#{oPath}/edge_#{counter}")
		# system "head #{oPath}/node_#{counter}"
		# node%0,cluster,support,frequency,total
		# a,#1_1,0.3636363636,4,11
		# b,#1_1,0.3636363636,4,11
		# system "head #{oPath}/edge_#{counter}"
		# node1%0,node2%1,cluster,support
		# a,b,#1_1,0.1818181818
		# a,d,#1_1,0.1818181818

#system "cp #{xxtra} #{oPath}/tra_#{counter}"
#	break if counter==3
		counter+=1
		system "cp #{xxtra2} #{xxtra}"
	end
end

### mtra2gc用パラメータ
paramTra2gc=""
paramTra2gc << " tid=#{idFN}"    if idFN
paramTra2gc << " item=#{itemFN}" if itemFN
paramTra2gc << " s=#{sp1}"       if sp1
paramTra2gc << " S=#{sp2}"       if sp2
#####################
# 異なる向きのconfidenceを列挙するためにsim=C th=0として双方向列挙しておく
# 出力データは倍になるが、mfriendsで-directedとすることで元が取れている
paramTra2gc << " sim=C"
paramTra2gc << " th=0"
#####################
paramTra2gc << " -node_support"  if node_support
paramTra2gc << " -num"           if numtp

### polish用パラメータ
paramPolish=""
paramPolish << " sim=#{simStr}"
paramPolish << " rank=#{rank}" if rank

### クラスタリング用パラメータ
paramCluster=""

temp=MCMD::Mtemp.new
xxhis=temp.file
MCMD::mkDir(xxhis,true) # 併合過程の履歴dir

# numtpの場合、数値item最大値を取得しておく
maxNo=nil # hiPolishで更新され、最終的に最後のcluster item番号となる
lastItemNo=nil # オリジナルのtra上のitem番号の最大値
if numtp then
	maxNo=getMaxNo(traFile,itemFN)
	lastItemNo=maxNo
end

# 階層化研磨(hierarchical polishing)実行
hiPolish(traFile,idFN,itemFN,simStr,paramTra2gc,paramPolish,paramCluster,maxLevel,xxhis,maxNo)

# node,edgeの最終出力
outputNode(xxhis,lastItemNo,onFile)
outputEdge(xxhis,simStr,oeFile)

# end message
MCMD::endLog(args.cmdline)

