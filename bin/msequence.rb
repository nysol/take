#!/usr/bin/env ruby
# encoding: utf-8

require "fileutils"
require "nysol/seqDB"
require "nysol/taxonomy"
require "nysol/enumLcmEsp"
require "nysol/enumLcmSeq"


$cmd=$0.sub(/.*\//,"")
$version="1.0"

def help
STDERR.puts <<EOF
------------------------
#{$cmd} version #{$version}
------------------------
概要) LCM_seqにより多頻度系列パターンを列挙する
特徴) 1) 
書式) #{$cmd} i= [x=] [O=] [tid=] [item=] [time=] [taxo=] [class=] [s=] [S=] [sx=] [Sx=] [l=] [u=] [top=] [p=] [g=] [w=] [Z=] [T=] [--help]

例1) #{$cmd} i=weblog.csv c=customer.csv tid=traID item=page time=アクセス時刻 class=購買
例2) #{$cmd} i=weblog.csv tid=traID item=page time=アクセス時刻

  ファイル名指定
  i= : アイテム集合データベースファイル名【必須】
  c= : クラスファイル名【オブション】
  x= : taxonomyファイル名【オブション】*1
  O= : 出力ディレクトリ名【オプション:default:./take_現在日付時刻】

  項目名指定
  tid=   : トランザクションID項目名(i=,c=上の項目名)【オプション:default="tid"】
  time=  : 時間項目名(i=上の項目名)【オプション:default="time"】
  item=  : アイテム項目名(i=,t=上の項目名)【オプション:default="item"】
  class= : クラス項目名(c=上の項目名)【オプション:default="class"】
  taxo=  : 分類項目名を指定する【条件付き必須:x=】

  列挙パラメータ
  s=   : 最小支持度(support)【オプション:default:0.05, 0以上1以下の実数】
  S=   : 最小支持件数【オプション】
  sx=  : 最大支持度(support)【オプション:default:1.0, 0以上1以下の実数】
  Sx=  : 最大支持件数【オプション】
  l=   : パターンサイズの下限(1以上20以下の整数)【オプション:default:制限なし】
  u=   : パターンサイズの上限(1以上20以下の整数)【オプション:default:制限なし】
  p=   : 最小事後確率【オプション:default:0.5】
  g=   : 最小増加率【オプション】
  gap= : パターンのギャップ長の上限(0以上の整数)【オプション:0で制限無し,default:0】
  win= : パターンのウィンドウサイズの上限(0以上の整数)【オプション:0で制限無し,default:0】
  -padding : 時刻を整数とみなし、連続でない時刻に特殊なアイテムがあることを想定する。
           : gap=やwin=の指定に影響する。
  top=  : 列挙するパターン数の上限【オプション:default:制限なし】*2

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

  注釈
  *1 x=が指定されたとき、item項目の値を対応するtaxonomyに変換して実行する。例えば、アイテムa,bのtaxonomyをX、c,dのtaxonomyをYとすると、
     シーケンス"aeadd"は"XeXYY"に変換される。
  *2 top=が指定された時の動作: 例えばtop=10と指定すると、支持度が10番目高いパターンの支持度を最小支持度として頻出パターンを列挙する。よって、同じ支持度のパターンが複数個ある場合は10個以上のパターンが列挙されるかもしれない。

# より詳しい情報源 http://www.nysol.jp
# LCM_seqの詳しい情報源 http://research.nii.ac.jp/~uno/codes-j.htm
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
args=MCMD::Margs.new(ARGV,"i=,c=,x=,O=,tid=,time=,item=,class=,taxo=,s=,S=,sx=,Sx=,g=,p=,-uniform,l=,u=,top=,gap=,win=,-padding,T=,-mcmdenv,-m,-c,-q")

# lcm_seqコマンド実行可能確認
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmSeq::CMD      , "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmSeq::CMD_ZERO , "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmSeq::CMD_TRANS, "-v", "lcm_trans 1.0"))

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

iFile   = args.file("i=","r")
xFile   = args.file("x=","r")

t=Time.now
outPath = args.file("O=", "w", "./take_#{sprintf('%d%02d%02d%02d%02d%02d',t.year,t.month,t.day,t.hour,t.min,t.sec)}")

idFN   = args.field("tid=",     iFile, "tid"  )
timeFN = args.field("time=",    iFile, "time" )
itemFN = args.field("item=",    iFile, "item" )
clsFN  = args.field("class=",   iFile, nil    )
taxoFN = args.field("taxo=",    xFile, "taxo" )
idFN   = idFN["names"].join(",")   if idFN
timeFN = timeFN["names"].join(",") if timeFN
itemFN = itemFN["names"].join(",") if itemFN
clsFN  = clsFN["names"].join(",")  if clsFN
taxoFN = taxoFN["names"].join(",") if taxoFN

sortInfo =  args.bool("-q") 


eArgs=Hash.new
eArgs["minSup" ] = args.float("s="   ,0.05 ,0,1    ) # 最小サポート
eArgs["minCnt" ] = args.  int("S="   ,nil  ,1,nil  ) # 最小サポート件数
eArgs["maxSup" ] = args.float("sx="  ,nil  ,0,1    ) # 最小サポート
eArgs["maxCnt" ] = args.  int("Sx="  ,nil  ,1,nil  ) # 最小サポート件数
eArgs["minProb"] = args.float("p="   ,0.5  ,0.5,1  ) # 最小事後確率
eArgs["minGR"  ] = args.float("g="   ,nil  ,1.0,nil) # 最小GR
eArgs["uniform"] = args. bool("-uniform") # クラス事前確率を一様と考えるかどうか
eArgs["minLen" ] = args.  int("l="   ,nil  ,1,nil  )
eArgs["maxLen" ] = args.  int("u="   ,nil  ,1,nil  )
eArgs["gap"    ] = args.  int("gap=" ,nil  ,0,nil  ) # gap長上限限
eArgs["win"    ] = args.  int("win=" ,nil  ,0,nil  ) # win size上限限
eArgs["padding"] = args. bool("-padding") # 0item ommit
eArgs["top"    ] = args.  int("top=" ,nil,0)
eArgs["exM"] = args. bool("-m") # extension maximal patterns only
eArgs["exC"] = args. bool("-c") # extension closed patterns only


if eArgs["exM"] and eArgs["exC"] then
	raise "-m cannot be specified with -c"
end

if eArgs["minLen"] and eArgs["maxLen"]
	if eArgs["minLen"] > eArgs["maxLen"] then
		raise "u= must be greater than or equal to l="
	end
end

if eArgs["gap"] and eArgs["win"]
	if eArgs["gap"] > eArgs["win"] then
		raise "win= must be greater than or equal to gap="
	end
end

# seq型DBの読み込み
db=TAKE::SeqDB.new(iFile,idFN,timeFN,itemFN,eArgs["padding"],clsFN)
#db.show

# taxonomyのセット
taxo=nil
if xFile!=nil then
	taxo=TAKE::Taxonomy.new(xFile,itemFN,taxoFN)
	db.repTaxo(taxo) # seqはtaxonomyの置換のみ
end

# パターン列挙
lcm=nil
if clsFN then
	lcm=TAKE::LcmEsp.new(db);
	lcm.enumerate(eArgs)
else
	lcm=TAKE::LcmSeq.new(db);
	lcm.enumerate(eArgs)
end

# 出力
system("mkdir -p #{outPath}")
lcm.output(outPath,sortInfo)

MCMD::msgLog("The final results are in the directory `#{outPath}'")

# 終了メッセージ
MCMD::endLog(args.cmdline)

