#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# 1.0 initial development: 2016/12/23
# 1.1 dir=x追加: 2016/12/29
# 1.2 jac=等追加: 2017/1/10
# 1.3 ro=追加: 2017/1/15
$version="1.3"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) トランザクションデータから２アイテム相関ルールを求め、ランクに基づいた類似関係にある相関ルールを選択する

書式) #{$cmd} i= tid= item= [class=] [ro=] [no=] eo= s=|S= [filter=] [lb=] [ub=] [sim=] [rank=] [dir=] [-prune] [T=] [--help]
  i=     : トランザクションデータファイル【必須】
  tid=   : トランザクションID項目名【必須】
  item=  : アイテム項目名【必須】
  ro=    : 出力ルールファイル
  no=    : 出力ファイル(節点)
  eo=    : 出力ファイル(辺:節点ペア)
  s=     : 最小支持度(全トランザクション数に対する割合による指定): 0以上1以下の実数
  S=     : 最小支持度(トランザクション数による指定): 1以上の整数
  filter=: 相関ルールの評価指標(省略可,複数指定可)
           指定できる類似度は以下の4つ(括弧内は値域)。
             J: Jaccard(0..1), P:normalized PMI(-1..0..1), C:Confidence(0..1)
  lb=    : filter=で指定した相関ルール評価指標の下限値
  ub=    : filter=で指定した相関ルール評価指標の上限値
           lb=が省略された場合のデフォルトで0、ub=のデフォルトは1
  例1: sim=P lb=0.5 : normalized PMIが0.5以上1以下の相関ルールを列挙する
  例2: sim=P,C lb=0.5,0.2 ub=,0.8 : 例1に加えて、confidenceが0.2以上0.8以下の相関ルールを列挙する

  sim=   : 列挙された相関ルールを元にして枝を張る条件となる指標を指定する。
           以下に示す4つの相関ルール評価指標が指定できる(デフォルト:S)。
             S:Support, J: Jaccard, P:normalized PMI, C:Confidence
  rank=  : 枝を張る条件で、類似枝の上位何個までを選択するか(デフォルト:3)
  dir=   : 双方向類似関係(b)のみを出力するか、単方向類似関係(m)のみか、両方とも含める(x)かを指定する。(デフォルト:b)
           相関ルールa=>bの類似度をsim(a=>b)としたとき、
           b:(bi-directional) sim(a=>b)およびsim(b=>a)がrank=で指定した順位内である相関ルールのみ選択される。
           m:(mono-directional) 片方向の類似度のみが、指定された順位内である相関ルールが選択される。
           x:(both) bとmの両方共含める。
  以上の3つのパラメータは複数指定することが可能(3つまで)。
  例1: sim=S dir=b rank=3 :
         アイテムaからみてsupport(a=>b)が3位以内で、かつ
         アイテムbからみてsupport(b=>a)も3位以内であるような相関ルールを選択する
  例2: sim=S,C dir=b,m rank=3,1
         例1に加えて、アイテムaから見てconfidenc(a=>b)が3以内、もしくは
         アイテムbから見てconfidenc(b=>a)が3以内であれば、そのような相関ルールも選択する
  -prune : sim=等を複数指定した場合、マルチ枝を単一化する。
           第1優先順位: 双方向>片方向
           第2優先順位: パラメータ位置昇順

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力ファイル形式)
トランザクションIDとアイテムの２項目によるトランザクションデータ。

o=の出力形式)
枝ファイル: simType,simPriority,node1,node2,sim,dir,color
節点ファイル: node,support,frequency,total

例)
$ cat tra.csv
id,item
1,a
1,b
2,a
2,b
3,a
3,b
4,b
4,c
5,a
5,c
6,a
6,c
7,d
7,e
8,d
8,e
9,d
9,e
A,d
A,c
B,e
B,b
C,e
C,a
D,f
D,c
E,f
E,b
F,f
F,a

$ #{$cmd} i=tra1.csv no=node11.csv eo=edge11.csv tid=id S=1 item=item sim=S rank=1 dir=b
$ cat edge11.csv 
simType,simPriority,node1,node2,sim,dir,color
support,0,a,e,0.2727272727,W,FF0000
support,0,d,e,0.2727272727,W,FF0000
support,0,c,f,0.1818181818,W,FF0000
support,0,g,h,0.1818181818,W,FF0000

$ #{$cmd} i=tra2.csv no=node51.csv eo=edge51.csv tid=id S=1 item=item sim=S,C rank=1,1 dir=b,m -prune
$ cat edge51.csv 
simType,simPriority%3n,node1%0,node2%1,sim,dir%2r,color
support,0,a,b,0.2,W,FF0000
confidence,1,c,a,0.4,F,8888FF
support,0,d,e,0.2,W,FF0000
confidence,1,f,a,0.3333333333,F,8888FF
confidence,1,f,b,0.3333333333,F,8888FF
confidence,1,f,c,0.3333333333,F,8888FF

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

args=MCMD::Margs.new(ARGV,"i=,tid=,item=,ro=,eo=,no=,s=,S=,filter=,lb=,ub=,sim=,dir=,rank=,-prune,-num,-verbose","i=,tid=,item=,eo=,no=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end
iFile  = args.str("i=")
idFN   = args.str("tid=")
itemFN = args.str("item=")
sp1    = args.str("s=")
sp2    = args.str("S=")
#node_support=args.bool("-node_support")
numtp   = args.bool("-num")

filter= args.str("filter=","",",")
ub    = args.str("ub="  ,"",",")
lb    = args.str("lb="  ,"",",")

sim   = args.str("sim=" ,"S",",")
dir   = args.str("dir=" ,"b",",")
rank  = args.str("rank=","3",",")
prune = args.bool("-prune")

# chicking parameter for filter=
if filter.size>0
	unless lb
		MCMD::errorLog("lb= have to be set with filter=")
		raise ArgumentError
	end

	(0...filter.size-1).each{|i|
		(i...filter.size).each{|j|
			next if i==j
			if filter[i]==filter[j]
				MCMD::errorLog("filter= cannot take same values")
				raise ArgumentError
			end
		}
	}

	if filter.size>3
		MCMD::errorLog("flter=,lb=,ub= takes parameters with 0<size<=3")
		raise ArgumentError
	end

	filter.each{|s|
		unless ["J","P","C"].index(s)
			MCMD::errorLog("filter= takes J, P or C")
			raise ArgumentError
		end
	}

	filterStr=[]
	(0...filter.size).each{|i|
		if    filter[i]=="J"
			filterStr[i]="jaccard"
		elsif filter[i]=="P"
			filterStr[i]="PMI"
		elsif filter[i]=="C"
			filterStr[i]="confidence"
		end
	}

	lbStr=[]
	lbStr << (lb and lb[0]) ? lb[0]:0
	lbStr << (lb and lb[1]) ? lb[1]:0
	lbStr << (lb and lb[2]) ? lb[2]:0

	ubStr=[]
	ubStr << (ub and ub[0]) ? ub[0]:1
	ubStr << (ub and ub[1]) ? ub[1]:1
	ubStr << (ub and ub[2]) ? ub[2]:1

end

# chicking parameter for sim=
(0...sim.size-1).each{|i|
	(i...sim.size).each{|j|
		next if i==j
		if sim[i]==sim[j]
			MCMD::errorLog("sim= cannot take same values")
			raise ArgumentError
		end
	}
}

if sim.size>3
	MCMD::errorLog("sim=,dir=,rank= takes parameters with 0<size<=3")
	raise ArgumentError
end

unless sim.size==dir.size and dir.size==rank.size
	MCMD::errorLog("sim=,dir=,rank= must take same size of parameters")
	raise ArgumentError
end

sim.each{|s|
	unless ["S","J","P","C"].index(s)
		MCMD::errorLog("sim= takes S, J, P or C")
		raise ArgumentError
	end
}

dir.each{|s|
	unless ["b","m","x"].index(s)
		MCMD::errorLog("dir= takes b, m, x")
		raise ArgumentError
	end
}

rank.each{|s|
	if s.to_i<0
		MCMD::errorLog("rank= takes positive integer")
		raise ArgumentError
	end
}

simStr=[]
(0...sim.size).each{|i|
	if    sim[i]=="S"
		simStr[i]="support"
	elsif sim[i]=="J"
		simStr[i]="jaccard"
	elsif sim[i]=="P"
		simStr[i]="PMI"
	elsif sim[i]=="C"
		simStr[i]="confidence"
	end
}

orFile  = args. file("ro=", "w")
onFile  = args. file("no=", "w")
oeFile  = args. file("eo=", "w")

# ============
# entry point
temp=MCMD::Mtemp.new
xxsimgN=temp.file
xxsimgE0=temp.file
xxsimgE=temp.file
xxfriendE=temp.file
xxrecs2=temp.file
xxfriends=temp.file
xxw=temp.file
xxf=temp.file
xxff=temp.file
xxor=temp.file

### mtra2g.rb
param  = "i=#{iFile}"
param << " tid=#{idFN}"    if idFN
param << " item=#{itemFN}" if itemFN
param << " s=#{sp1}"       if sp1
param << " S=#{sp2}"       if sp2

#####################
# 異なる向きのconfidenceを列挙するためにsim=C th=0として双方向列挙しておく
# 出力データは倍になるが、mfriendsで-directedとすることで元が取れている
param << " sim=C"
param << " th=0"
#####################
param << " -node_support"
param << " -num"           if numtp
system "mtra2gc.rb #{param} no=#{xxsimgN} eo=#{xxsimgE0}"
#puts "mtra2gc.rb #{param} no=#{xxsimgN} eo=#{xxsimgE}"
#system "cp #{xxsimgE} xxsimgE"
if filter.size>0
	f=""
	f << "mselnum f=#{filterStr[0]} c='[#{lb[0]},#{ubStr[0]}]' i=#{xxsimgE0} |"
	f << "mselnum f=#{filterStr[1]} c='[#{lb[1]},#{ubStr[1]}]' |" if filterStr[1]
	f << "mselnum f=#{filterStr[2]} c='[#{lb[2]},#{ubStr[2]}]' |" if filterStr[2]
	f << "cat >#{xxsimgE}"
	system(f)
else
	system "mv #{xxsimgE0} #{xxsimgE}"
end

col=[
["FF000080","FF888880"],
["0000FF80","8888FF80"],
["00FF0080","88FF8880"]
]

# friendの結果dir
MCMD::mkDir(xxfriends,true)
(0...sim.size).each{|i|
	param  = "ei=#{xxsimgE}"
	param << " ni=#{xxsimgN}"
	param << " ef=node1,node2"
	param << " nf=node"
	param << " sim=#{simStr[i]}"
	param << " -directed"
	param << " dir=#{dir[i]}" if dir[i]
	param << " rank=#{rank[i]}"
	system "mfriends.rb #{param} eo=#{xxfriendE} no=#{xxfriends}/n_#{i}"

#system "msortf f=node1,node2,#{simStr[i]}%nr i=#{xxfriendE}"

	# 双方向枝を統合するする
	# 枝が2本=双方向枝を選択
	f=""
	f << "mfsort f=node1,node2 i=#{xxfriendE} |"
	f << "msummary k=node1,node2 f=#{simStr[i]} c=count,mean |"
	# node1%0,node2%1,fld,count,mean
	# a,b,support,2,0.1818181818
	# a,d,support,2,0.1818181818
	f << "mselstr f=count v=2 o=#{xxrecs2}"
	system(f)
#system "msortf f=node1,node2 i=#{xxrecs2}"

	f=""
	f << "mjoin k=node1,node2 K=node1,node2 m=#{xxrecs2} f=mean:s1 -n i=#{xxfriendE} |"
	f << "mjoin k=node2,node1 K=node1,node2 m=#{xxrecs2} f=mean:s2 -n |"
	# 1) xxrecs2でsimをjoinできない(s1,s2共にnull)ということは、それは片方向枝なので"F"をつける
	# 2) 双方向枝a->b,b->aのうちa->bのみ(s1がnullでない)に"W"の印をつける。
	# 3) それ以外の枝は"D"として削除
	f << "mcal c='if(isnull($s{s1}),if(isnull($s{s2}),\"F\",\"D\"),\"W\")' a=dir |"
	f << "mselstr f=dir v=D -r |"
	f << "mcal c='if($s{dir}==\"W\",$s{s1},$s{#{simStr[i]}})' a=sim |"
	f << "mchgstr f=dir:color c=W:#{col[i][0]},F:#{col[i][1]} -A |"
	f << "msetstr v=#{simStr[i]},#{i} a=simType,simPriority |"
	f << "mcut f=simType,simPriority,node1,node2,sim,dir,color o=#{xxfriends}/e_#{i}"
	system(f)
	# node1%1,node2%0,simType,sim,dir,color
	# b,a,jaccard,0.3333333333,F,8888FF
	# j,c,jaccard,0.3333333333,F,8888FF
	# b,d,jaccard,0.3333333333,F,8888FF
	# a,e,jaccard,0.5,W,0000FF
	# d,e,jaccard,0.5,W,0000FF
}

# rule fileの出力
if orFile
	system "mcat i=#{xxfriends}/e_* | muniq k=node1,node2 o=#{xxor}"
	f=""
	f << "mcommon k=node1,node2 m=#{xxor} i=#{xxsimgE} o=#{orFile}"
	system(f)
end

# マルチ枝の単一化(W優先,パラメータ位置優先)
if prune
	# 双方向と片方向に分割
	f=""
	f << "mcat i=#{xxfriends}/e_* |"
	f << "mselstr f=dir v=W o=#{xxw} u=#{xxf}"
	system(f)
#puts "----------xxw"
#system "cat #{xxw}"
#puts "----------xxf"
#system "cat #{xxf}"
	# 片方向のみの枝を選択
	f=""
	f << "mcommon k=node1,node2 K=node1,node2 -r m=#{xxw} i=#{xxf} |"
	f << "mcommon k=node1,node2 K=node2,node1 -r m=#{xxw} o=#{xxff}"
	system(f)
#puts "----------xxff"
#system "cat #{xxff}"

	# catして、双方向がダブってたら単一化する
	f=""
	f << "mcat i=#{xxw},#{xxff} |"
	f << "mbest k=node1,node2 s=dir%r,simPriority%n o=#{oeFile}"
	system(f)
else
	system "mcat i=#{xxfriends}/e_* o=#{oeFile}"
end
system "mv #{xxfriends}/n_0 #{onFile}"

#system "m2gv.rb -noiso ni=#{onFile} nf=node nv=support ei=#{oeFile} ef=node1,node2 ed=dir ec=color ev=sim -d o=#{dotFile}"

# end message
MCMD::endLog(args.cmdline)

