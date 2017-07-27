#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"
require "nysol/take"
require "nysol/enumLcmIs"

# ver="1.0" # 初期リリース 2014/8/2
# ver="1.1" # アイテムの数値ソートに関するバグ修正 2015/9/8
# ver="1.2" # null値が含まれる場合にmappingテーブルがずれるバグ修正 2015/10/1
$cmd=File.basename($0)
$version="1.2"

def help

STDERR.puts <<EOF
----------------------------
mbiclique.rb version #{$version}
----------------------------
概要) lcmによる極大二部クリークの列挙
内容) 二部グラフデータを入力として、極大二部クリークを列挙する。
書式) mbiclique.rb ei= [ef=] [o=] [l=] [u=] [o=] [-edge] [T=] [-debug] [--help]

  ファイル名指定
  ei=    : 辺データファイル
  ef=    : 辺データ上の2つの部項目名(省略時は"node1,node2")
  o=     : 出力ファイル
  l=     : 二部クリークを構成する最小節点数(ここで指定したサイズより小さいクリークは列挙されない)
         : カンマで区切って2つの値を指定すると、各部のサイズを制限できる
         : 1つ目の値はef=で指定した1つ目の部に対応し、2つ目の値は2つ目に指定した部に対応する。
  u=     : クリークを構成する最大節点数(ここで指定したサイズより大きいクリークは列挙されない)
         : カンマで区切って2つの値を指定すると、各部のサイズを制限できる
	-edge  : 枝による出力(クリークIDと枝(節点ペア)で出力する)

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力形式)
二部グラフの節点ペアを項目で表現したCSVデータ。

出力形式1)
二部クリークを構成する全節点を各部ごとにベクトル形式で出力する。
出力項目は、"節点項目名1,節点項目名2,size1,size2"の4項目で、節点名1と節点名2は、ef=で指定された名称が利用される。
節点項目名1,節点項目名2に出力される値が節点名ベクトルである(一行が一つの二部クリークに対応)ことが異なる。
idはクリークの識別番号で、一つのクリークは同じid番号が振られる。id番号そのものに意味はない。
節点項目名1,節点項目名2には、各部を構成する節点名のベクトルが出力される。
size1,size2は二部クリークを構成する各部の節点数である。

出力形式2) -edge を指定した場合の出力形式
クリークIDと二部クリークを構成する全枝(節点ペア)を出力する。
出力項目は"id,節点項目名1,節点項目名2,size"の4項目である。
例えば各部のサイズが3,4であるような二部クリークは12行の枝データとして出力される。
出力形式1に比べてファイルサイズは大きくなる。


例1)
$ cat data1.csv
node1,node2
a,A
a,B
a,C
b,A
b,B
b,D
c,A
c,D
d,B
d,C
d,D

$ mclique.rb ei=data1.csv ef=n1,n2 o=out1.csv
#MSG# converting paired form into transaction form ...; 2014/03/24 11:52:05
#MSG# lcm_20140215 CIf /tmp/__MTEMP_47150_70177387663280_0 1 /tmp/__MTEMP_47150_70177387663280_3; 2014/03/24 11:52:05
trsact: /tmp/__MTEMP_47150_70177387663280_0 ,#transactions 4 ,#items 4 ,size 11 extracted database: #transactions 4 ,#items 4 ,size 11
output to: /tmp/__MTEMP_47150_70177387663280_3
separated at 0
11
1
3
4
3
iters=11
#END# mbiclique.rb ei=data1.csv o=out1.csv ef=node1,node2
$ cat out1.csv 
node1,node2,size1,size2
a,A B C,1,3
a b,A B,2,2
a b c,A,3,1
a b d,B,3,1
a d,B C,2,2
b,A B D,1,3
b c,A D,2,2
b c d,D,3,1
b d,B D,2,2
d,B C D,1,3

例3) 枝による出力(-edgeの指定)
$ mclique.rb ei=data1.csv ef=n1,n2 o=out2.csv
#END# ../../bin/mbiclique.rb ei=data/data1.csv o=xxresult/out11.csv ef=node1,node2 -edge
$ cat out2.csv 
id,node1,node2,size1,size2
1,c,A,3,1
1,a,A,3,1
1,b,A,3,1
10,d,B,1,3
10,d,C,1,3
10,d,D,1,3
2,b,B,3,1
2,a,B,3,1
2,d,B,3,1
   :

例3) 部node1の最小サイズを3に制限
$ mbiclique.rb ei=data1.csv o=out3.csv ef=node1,node2 l=3,
#END# mbiclique.rb ei=data1.csv o=out3.csv ef=node1,node2 l=3,
$ cat out3.csv 
node1,node2,size1,size2
a b c,A,3,1
a b d,B,3,1
b c d,D,3,1

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
args=MCMD::Margs.new(ARGV,"ei=,ef=,o=,l=,u=,-edge","ei=")

# コマンド実行可能確認
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD      , "executable"))

# コマンド実行可能確認
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD, "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD_TRANS, "-v", "lcm_trans 1.0"))

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

type="C"

byedge  = args.bool("-edge")
oFile   = args.file("o=", "w")
ei      = args. file("ei=","r") # edgeファイル名
ef1,ef2 = args.field("ef=", ei, "node1,node2",2,2)["names"]

minSizeStr = args.str("l=")    # クリークサイズ下限
maxSizeStr = args.str("u=")    # クリークサイズ上限
minSize1=nil
minSize2=nil
if minSizeStr then
	minSizeStr=minSizeStr.split(",",-1)
	if minSizeStr.size==1 then
		minSize1=minSizeStr[0].to_i if minSizeStr[0]!=""
		minSize2=minSizeStr[0].to_i if minSizeStr[0]!=""
	else
		minSize1=minSizeStr[0].to_i if minSizeStr[0]!=""
		minSize2=minSizeStr[1].to_i if minSizeStr[1]!=""
	end
end
if maxSizeStr then
	maxSizeStr=maxSizeStr.split(",",-1)
	if maxSizeStr.size==1 then
		maxSize1=maxSizeStr[0].to_i if maxSizeStr[0]!=""
		maxSize2=maxSizeStr[0].to_i if maxSizeStr[0]!=""
	else
		maxSize1=maxSizeStr[0].to_i if maxSizeStr[0]!=""
		maxSize2=maxSizeStr[1].to_i if maxSizeStr[1]!=""
	end
end

def pair2tra(ei,ef1,ef2,traFile,mapFile1,mapFile2)
	MCMD::msgLog("converting paired form into transaction form ...")
	wf=MCMD::Mtemp.new
	wf1=wf.file
	wf2=wf.file

	f=""
	f << "mcut f=#{ef1}:node1 i=#{ei} |"
	f << "mdelnull f=node1 |"
	f << "msortf f=node1 |"
	f << "muniq  k=node1 |"
	f << "mnumber s=node1 a=num1  o=#{mapFile1}"
	system(f)

	f=""
	f << "mcut    f=#{ef2}:node2 i=#{ei} |"
	f << "mdelnull f=node2 |"
	f << "msortf  f=node2 |"
	f << "muniq   k=node2 |"
	f << "mnumber s=node2 a=num2  o=#{mapFile2}"
	system(f)

	f=""
	f << "mcut f=#{ef1}:node1,#{ef2}:node2 i=#{ei} |"
	f << "msortf f=node1 |"
	f << "mjoin  k=node1 m=#{mapFile1} f=num1 |"
	f << "msortf f=node2 |"
	f << "mjoin  k=node2 m=#{mapFile2} f=num2 |"
	f << "mcut   f=num1,num2 |"
	f << "msortf f=num1,num2%n |"
	f << "mtra   k=num1 s=num2%n f=num2 |"
	f << "msortf f=num1%n |"
	f << "mcut   f=num2 -nfno o=#{traFile}"
	system(f)
end


wf=MCMD::Mtemp.new
xxtra=wf.file
xxmap1=wf.file
xxmap2=wf.file
pair2tra(ei,ef1,ef2,xxtra,xxmap1,xxmap2)
#system "cp #{xxtra} xxtra"
#system "cp #{xxmap1} xxmap1"
#system "cp #{xxmap2} xxmap2"

# 利用コマンドファイル名
#CMD="lcm_20140215"

run=""
run << "#{type}If"
run << " -l #{minSize2}" if minSize2 # パターンサイズ下限
run << " -u #{maxSize2}" if maxSize2 # パターンサイズ上限

# lcm出力ファイル
lcmout = wf.file
# 頻出パターンがなかった場合、lcm出力ファイルが生成されないので
# そのときのために空ファイルを生成しておいく。
system("touch #{lcmout}")

# lcm実行
minCnt=1
MCMD::msgLog("#{run} #{xxtra} #{minCnt} #{lcmout}")
TAKE::run_lcm("#{run} #{xxtra} #{minCnt} #{lcmout}")
#system("#{run} #{xxtra} #{minCnt} #{lcmout}")
#system "cp #{lcmout} lcmout"

xxp0=wf.file
xxt0=wf.file

TAKE::run_lcmtrans(lcmout,"p",xxt0)

f=""
#f << "#{TAKE::LcmIs::CMD_TRANS} #{lcmout} p |" # pattern,count,size,pid
f << "mdelnull  f=pattern  i=#{xxt0}                  |"
f << "mvreplace vf=pattern m=#{xxmap2} K=num2 f=node2 |"
f << "mcut      f=pid,pattern,size:size2            |"
f << "mvsort    vf=pattern                          |"
f << "msortf    f=pid                               o=#{xxp0}"
system(f)
#system "cp #{xxp0} xxp0"

if byedge then
	xx1=wf.file
	xx2=wf.file
	xx3=wf.file

	system "mtra f=pattern i=#{xxp0} -r o=#{xx1}"

	xx3t=wf.file
	TAKE::run_lcmtrans(lcmout,"t",xx3t)

	f=""
	#f << "#{TAKE::LcmIs::CMD_TRANS} #{lcmout} t |" #__tid,pid
	#f << "mcal c='${__tid}+1' a=_tid                 |"
	f << "msortf f=__tid i=#{xx3t}                    |"
	f << "mjoin  k=__tid m=#{xxmap1} f=node1 K=num1   |"
	f << "msortf f=pid o=#{xx2}"
	system(f)

	f=""
	f << "mcount k=pid a=size1 i=#{xx2} |"
	f << "mselnum f=size1 c='[#{minSize1},#{maxSize1}]' o=#{xx3}"
	system(f)

	f = ""
	f << "mjoin  k=pid m=#{xx3} f=size1 i=#{xx2} |"
	f << "mnjoin k=pid m=#{xx1} f=pattern,size2       |"
	f << "mcut   f=pid:id,node1:#{ef1},pattern:#{ef2},size1,size2 o=#{oFile}"
	system(f)
else

	xx4t=wf.file
	TAKE::run_lcmtrans(lcmout,"t",xx4t)

	f=""
	#f << "#{TAKE::LcmIs::CMD_TRANS} #{lcmout} t |" #__tid,pid
	#f << "mcal c='${__tid}+1' a=_tid                 |"
	f << "msortf f=__tid i=#{xx4t}                    |"
	f << "mjoin  k=__tid m=#{xxmap1} f=node1 K=num1   |"
	f << "msortf f=pid                                |"
	f << "mtra   k=pid f=node1 |"
	f << "mvcount vf=node1:size1 |"
	f << "mjoin  k=pid m=#{xxp0} f=pattern,size2 |"
	f << "mselnum f=size1 c='[#{minSize1},#{maxSize1}]' |"
	f << "mvsort vf=node1,pattern |"
	f << "msortf f=node1,pattern |"
	f << "mcut   f=node1:#{ef1},pattern:#{ef2},size1,size2     o=#{oFile}"
	system(f)
end
# 終了メッセージ
MCMD::endLog(args.cmdline)

