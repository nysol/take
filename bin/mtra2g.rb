#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/traDB.rb"
require "nysol/taxonomy.rb"
require "nysol/enumLcmEp"
require "nysol/enumLcmIs"

# ver="1.0" # 初期リリース 2014/2/20
# ver="1.1" # 出力ファイルにfrequency追加 2016/8/11
# ver="1.2" # mtra2g.rbを大幅改良 2016/9/28
#             クラスファイル対応,edgeに各種類似度追加,節点名順ソート
$cmd=$0.sub(/.*\//,"")
$version="1.2"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) トランザクションデータからアイテム類似グラフを構築する。
内容) 2アイテムの共起情報によって類似度を定義し、ある閾値より高い類似度を持つアイテム間に枝を張る。
書式) #{$cmd} i= tid= item= [class=] [no=] eo= s=|S= [sim=] [th=] [log=] [T=] [--help]

  ファイル名指定
  i=     : トランザクションデータファイル【必須】
  tid=   : トランザクションID項目名【必須】
  item=  : アイテム項目名【必須】
  classs=: クラス項目名
  no=    : 出力ファイル(節点)
  eo=    : 出力ファイル(辺:節点ペア)
  log=   : パラメータの設定値をkey-value形式のCSVで保存するファイル名

  【枝を張る条件1:省略時はs=0.01】
  s=     : 最小支持度(全トランザクション数に対する割合による指定): 0以上1以下の実数
  S=     : 最小支持度(トランザクション数による指定): 1以上の整数
         : s=,S=のいずれかが条件として採用される。
         : s=,S=共に指定しなければ、s=0.01が指定されたとして動作する。
         : s=,S=共に指定されればS=優先される。
         : クラスを指定した場合、各クラス別に最小支持度を変更することもできる。
         : クラスがc1,c2の二つで、それぞれに0.01,0.02を指定したい場合は以下の通り指定する。
         : s=c1:0.01,c2:0.02

  【枝を張る条件2:省略可】
  sim=   : 枝を張る条件2: 枝を張るために用いる類似度を指定する。
           指定できる類似度は以下の4つのいずれか一つ。
             R (Resemblance)          : |A ∩ B|/|A ∪ B|
             P (normalized PMI)       : log(|A ∩ B|*T / (|A|*|B|)) / log(|A ∩ B|/T)
                                        liftを-1〜+1に基準化したもの。
                                        -1:a(b)出現時b(a)出現なし、0:a,b独立、+1:a(b)出現時必ずb(a)出現
             G (Growth rate)          : (|A_p ∩ B_p|/T_p)/(|A_n ∩ B_n|/T_n)
             T (Posterior probability): Gの確率表現(アイテムA,Bを観測した時のそれが対象クラスである事後確率)
                A  :アイテムaを含むトランザクション集合
                T  : 全トランザクション数。
                A_p:対象クラスでアイテムaを含むトランザクション集合
                A_n:対象クラス以外でアイテムaを含むトランザクション集合
                T_p:対象クラスのトランザクション数
  th=    : sim=で指定された類似度について、ここで指定された値以上のアイテム間に枝を張る。

  【節点条件】
  -node_support : 節点にもs=,S=の条件を適用する。指定しなければ全てのitemを節点として出力する。
                  class=を指定した場合、節点のsupportはクラスを考慮せず、
                  全体のトランザクション数に対する割合として計算される。

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力ファイル形式)
トランザクションIDとアイテムの２項目によるトランザクションデータ。
class=を指定する場合は、さらにクラス項目が必要となる。
使用例を参照のこと。

出力形式)
a) 節点ファイル(no=)
例:
  node%0,support,frequency,total
  a,0.6,3,5
  b,0.8,4,5
  c,0.2,1,5
  d,0.8,4,5
  e,0.4,2,5
  f,0.8,4,5
項目の説明:
  node:アイテム
  support:frequency/total
  frequency:アイテムの出現頻度
  total:全トランザクション数

b) 枝ファイル(eo=)
例:
  node1%0,node2%1,support,frequency,frequency1,frequency2,total,lift,resemblance,PMI
  a,b,0.6,3,3,4,5,1.25,0.75,0.4368292054
  a,c,0.2,1,3,1,5,1.6667,0.3333333333,0.3173938055
項目の説明:
  node1,node2:アイテム
  support:frequency/total
  frequency:2つのアイテム(node1,node2)の共起頻度
  frequency1:node1の出現頻度
  frequency2:node2の出現頻度
  total:全トランザクション数
  lift: (total*frequency)/(frequency1*frequency2)
  resemblance,PMI:上述の「枝を張る条件2」を参照


c) class指定のある場合の枝ファイル(eo=)
例:
  class%0,node1%1,node2%2,support,frequency,frequency1,frequency2,total,lift,resemblance,PMI,growthRate,postProbability
  c1,b,f,0.6666666667,2,2,3,5,1.666666667,0.6666666667,0.5574929507,1.333333333,0.6666666667
  c1,d,f,0.6666666667,2,2,3,5,1.666666667,0.6666666667,0.5574929507,1.333333333,0.6666666667
  c2,a,b,1,2,2,2,5,2.5,1,1,3,0.6666666667
  c2,a,f,0.5,1,2,3,5,0.8333333333,0.25,-0.1132827526,1.5,0.5
項目の説明:
  class: クラス名
  node1〜PMI: b)に同じ
  growthRate,postProbability:上述の「枝を張る条件2」を参照
注意点:
  異なるクラスの枝情報が一つのファイルに出力されるので、クラス別のグラフとして扱いたい場合は、
  クラス別にファイルを分割する必要がある。

基本的な使用例)
$ cat tra1.csv 
id,item
1,a
1,b
1,c
1,f
2,d
2,e
2,f
3,a
3,b
3,d
3,f
4,b
4,d
4,f
5,a
5,b
5,d
5,e
$ #{$cmd} i=tra.csv tid=id item=item th=0.5 sim=R no=node.csv eo=edge.csv
##END# #{$cmd} i=tra.csv tid=id item=item th=0.5 sim=R no=node.csv eo=edge.csv; 2013/10/12 13:54:36
$ cat node.csv 
node,support
a,0.6
b,0.8
c,0.2
d,0.8
e,0.4
f,0.8
$ cat edge.csv
node1,node2,support,resemblance
a,b,0.6,0.75
d,b,0.6,0.6
e,d,0.4,0.5
f,b,0.6,0.6
f,d,0.6,0.6

クラス指定を伴う例)
$ cat tra2.csv 
id,item,class
1,a,c1
1,b,c1
1,c,c1
1,f,c1
2,d,c1
2,e,c1
2,f,c1
3,a,c2
3,b,c2
3,d,c2
3,f,c2
4,b,c1
4,d,c1
4,f,c1
5,a,c2
5,b,c2
5,d,c2
5,e,c2
$ m2tra2g.rb i=tra2.csv no=node.csv eo=edge.csv tid=id item=item th=1.5 sim=G class=class
#END# m2tra2g.rb i=tra2.csv no=node.csv eo=edge.csv tid=id item=item th=1.5 sim=G class=class; 2016/09/27 07:58:50
$ cat node.csv
node%0,support,frequency,total
a,0.6,3,5
b,0.8,4,5
c,0.2,1,5
d,0.8,4,5
e,0.4,2,5
f,0.8,4,5
$ cat edge.csv
class%0,node1%1,node2%2,support,frequency,frequency1,frequency2,total,lift,resemblance,PMI,growthRate,postProbability
c2,a,b,1,2,2,2,5,2.5,1,1,3,0.6666666667
c2,a,f,0.5,1,2,3,5,0.8333333333,0.25,-0.1132827526,1.5,0.5
c2,b,d,1,2,2,2,5,2.5,1,1,3,0.6666666667
c2,d,e,0.5,1,2,1,5,2.5,0.5,0.5693234419,1.5,0.5

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

# コマンド実行可能確認
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD      , "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD_ZERO , "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD_TRANS, "-v", "lcm_trans 1.0"))

args=MCMD::Margs.new(ARGV,"i=,x=,no=,eo=,log=,tid=,item=,class=,taxo=,s=,S=,sim=,th=,-node_support,top=,T=","i=,tid=,item=,eo=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

iFile   = args.file("i=","r")
xFile   = args.file("x=","r")

t=Time.now
onFile  = args. file("no=", "w")
oeFile  = args. file("eo=", "w")
logFile = args. file("log=", "w")

idFN   = args.field("tid=",  iFile, "tid"  )
itemFN = args.field("item=", iFile, "item" )
clsFN  = args.field("class=",iFile, nil    )
taxoFN = args.field("taxo=", xFile, "taxo" )
idFN   = idFN["names"].join(",")   if idFN
itemFN = itemFN["names"].join(",") if itemFN
clsFN  = clsFN["names"].join(",")  if clsFN
taxoFN = taxoFN["names"].join(",") if taxoFN

sim = args.  str("sim=")
th  = args.float("th=") # 類似度measure
node_support=args.bool("-node_support")

# 最小サポート確率
minSup=nil
sp=args.str("s=")
if sp==nil   ### s=指定なし
	minSup=nil

elsif sp.index(",") and sp.index(":") ### s=c1:0.1,c2:0.2,...
	minSup = {}
	sp=sp.split(",")
	(0...sp.size).each{|i|
		raise "bad format of s=" unless sp[i]
		kv=sp[i].split(":")
		raise "bad format of s=" unless kv[0] and kv[1]
		minSup[kv[0]]=kv[1].to_f
	}

else ### s=0.1
	minSup=sp.to_f
end

# 最小サポート件数
sp=args.str("S=")
if sp==nil   ### s=指定なし
	minCnt=nil

elsif sp.index(",") and sp.index(":") ### S=c1:10,c2:10,...
	minCnt = {}
	sp=sp.split(",")
	(0...sp.size).each{|i|
		raise "bad format of s=" unless sp[i]
		kv=sp[i].split(":")
		raise "bad format of s=" unless kv[0] and kv[1]
		minCnt[kv[0]]=kv[1].to_f
	}

else ### S=10
	minCnt=sp.to_f
end

# s=,S=両者指定ないときのデフォルト
if minSup==nil and minCnt==nil
	minSup=0.01
end

#top = args.int("top=" ,nil,0) # 今は使ってないがコメントを外せば機能するはず
uniform=args.bool("-uniform") # クラス事前確率を一様と考えるかどうか

if (sim and not th) or (not sim and th) then
	raise "th=(sim=) is mandatory when sim=(th=) is specified"
end

if sim and "RPGT".index(sim)==nil
	raise "sim= takes one of 'R','P','G','T'"
end

if sim=="G" and not clsFN
	raise "sim=G can be used with class="
end

if sim and "RP".index(sim) and clsFN
	raise "sim=R,P can not be specified with class="
end

# V型DBの読み込み
db=TAKE::TraDB.new(iFile,idFN,itemFN,clsFN)

=begin
# taxonomyのセット(今は未使用)
taxo=nil
if xFile!=nil then
	taxo=TAKE::Taxonomy.new(xFile,itemFN,taxoFN)
	if args.bool("-replaceTaxo") then
		db.repTaxo(taxo) # taxonomyの置換
	else
		db.addTaxo(taxo) # taxonomyの追加
	end
end
=end

simSel=""
simSel="mselnum f=resemblance     c='[#{th},]' |" if sim=="R"
simSel="mselnum f=PMI             c='[#{th},]' |" if sim=="P"
simSel="mselnum f=growthRate      c='[#{th},]' |" if sim=="G"
simSel="mselnum f=postProbability c='[#{th},]' |" if sim=="T"

t=Time.now
eArgs=Hash.new
eArgs["type"] = "F"
eArgs["maxSup"]=1.0
eArgs["uniform"] = uniform
eArgs["nomodel"] = true

# クラスありパターン列挙
if clsFN then
	# ノードはクラス関係なく全体でfrequentな2アイテムセットを求める
	lcm=TAKE::LcmIs.new(db,false);
	eArgs["minLen"] = 1
	eArgs["maxLen"] = 1
	if node_support
		eArgs["minSup"] = minSup
		eArgs["minCnt"] = minCnt
	else
		eArgs["minSup"] = 0
	end
	lcm.enumerate(eArgs)
	# pid,size,count,total,support%0nr,lift,pattern
	# 0,1,4,5,0.8,1,b
	# 1,1,4,5,0.8,1,d
	f=""
	f << "mcut f=pattern:node,support,count:frequency,total i=#{lcm.pFile} | msortf f=node o=#{onFile}"
	system(f)

	# エッジはGRにて求めるの
	# 1 itemset
	temp=MCMD::Mtemp.new
	xx1itemset=temp.file
	if sim=="G"
		eArgs["minGR"  ] = th # 最小GR
	elsif sim=="T"
		eArgs["minProb"] = th # 最小事後確率
	end
	eArgs["minLen"] = 1
	eArgs["maxLen"] = 1
	eArgs["minSup"] = minSup
	eArgs["minCnt"] = minCnt

	lcm=TAKE::LcmEp.new(db,false);
	lcm.enumerate(eArgs)
	# system "head #{lcm.pFile}"
	# class%0nr,pid,pattern,size,pos%2nr,neg,posTotal,negTotal,total,support,growthRate,postProb%1nr
	# c1,4,c,1,1,0,3,2,5,0.3333333333,inf,1
	# c1,0,f,1,3,1,3,2,5,1,2,0.75
	f=""
	f << "mcut f=pattern:node,support,pos:frequency,posTotal:total i=#{lcm.pFile} | msortf f=node o=#{xx1itemset}"
	system(f)
	# system "head #{onFile}"
	# class%0,node%1,frequency,total,support,negFrequency,negTotal
	# c1,b,2,3,0.6666666667,2,2
	# c1,c,1,3,0.3333333333,0,2

	# 2 itemset
	eArgs["minLen" ] = 2
	eArgs["maxLen" ] = 2
	eArgs["minSup"] = minSup
	eArgs["minCnt"] = minCnt
	lcm.enumerate(eArgs)
	# system "head #{lcm.pFile}"
	# class%0nr,pid,pattern,size,pos%2nr,neg,posTotal,negTotal,total,support,growthRate,postProb%1nr
	# c2,11,a d,2,2,0,2,3,5,1,inf,1
	# c1,9,e f,2,1,0,3,2,5,0.3333333333,inf,1
	f=""
	f << "msplit a=node1,node2 f=pattern i=#{lcm.pFile} |"
	f << "mfsort f=node1,node2 |"
	f << "mjoin k=node1 K=node m=#{xx1itemset} f=frequency:frequency1 |"
	f << "mjoin k=node2 K=node m=#{xx1itemset} f=frequency:frequency2 |"
	f << "mcal c='${pos}/(${frequency1}+${frequency2}-${pos})' a=resemblance |"
	f << "mcal c='if(${pos}!=0,(ln(${pos})+ln(${total})-ln(${frequency1})-ln(${frequency2}))/(ln(${total})-ln(${pos})),-1)' a=PMI |"
	f << "mcal c='(${pos}*${total})/((${frequency1}*${frequency2}))' a=lift |"
	f << "msortf f=class,node1,node2 |"
	f << simSel
	f << "mcut f=class,node1,node2,support,pos:frequency,frequency1,frequency2,total,lift,resemblance,PMI,growthRate,postProb:postProbability o=#{oeFile}"
	system(f)

# クラスなしパターン列挙
else
	lcm=TAKE::LcmIs.new(db,false);
	# 1 itemset
	eArgs["minLen" ] = 1
	eArgs["maxLen" ] = 1
	if node_support
		eArgs["minSup"] = minSup
		eArgs["minCnt"] = minCnt
	else
		eArgs["minSup"] = 0
	end
	lcm.enumerate(eArgs)
	# #{lcm.pFile}
	# pid,size,count,total,support%0nr,lift,pattern
	# 0,1,4,5,0.8,1,b
	# 1,1,4,5,0.8,1,d
	f=""
	f << "mcut f=pattern:node,support,count:frequency,total i=#{lcm.pFile} | msortf f=node o=#{onFile}"
	system(f)
	# node%0,support,frequency
	# a,0.6,3
	# b,0.8,4

	# 2 itemset
	eArgs["minLen" ] = 2
	eArgs["maxLen" ] = 2
	eArgs["minSup"] = minSup
	eArgs["minCnt"] = minCnt
	lcm.enumerate(eArgs)
	# #{lcm.pFile}
	# pid,size,count,total,support%0nr,lift,pattern
	# 0,2,3,5,0.6,0.9375,b d
	# 1,2,3,5,0.6,0.9375,b f
	f=""
	f << "msplit a=node1,node2 f=pattern i=#{lcm.pFile} |"
	f << "mfsort f=node1,node2 |"
	f << "mjoin k=node1 K=node m=#{onFile} f=frequency:frequency1 |"
	f << "mjoin k=node2 K=node m=#{onFile} f=frequency:frequency2 |"
	f << "mcal c='${count}/(${frequency1}+${frequency2}-${count})' a=resemblance |"
	f << "mcal c='(ln(${count})+ln(${total})-ln(${frequency1})-ln(${frequency2}))/(ln(${total})-ln(${count}))' a=PMI |"
	f << "msortf f=node1,node2 |"
	f << simSel
	f << "mcut f=node1,node2,support,count:frequency,frequency1,frequency2,total,lift,resemblance,PMI o=#{oeFile}"
	system(f)
	# node1%0,node2%1,support,frequency,frequency1,frequency2,total,lift,resemblance,PMI
	# a,b,0.6,3,3,4,5,1.25,0.75,0.4368292054
	# a,c,0.2,1,3,1,5,1.6667,0.3333333333,0.3173938055
end

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

