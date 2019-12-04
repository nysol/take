#!/usr/bin/env ruby
# encoding: utf-8

require "fileutils"
require "rubygems"
require "nysol/traDB.rb"
require "nysol/taxonomy.rb"
require "nysol/enumLcmEp"
require "nysol/enumLcmIs"

# ver="1.1" # コマンド版対応
# ver="1.2" # ヘルプ修正 2016/9/25
# ver="1.3" # maxSupにまつわるバグ修正 2017/1/14
$cmd=$0.sub(/.*\//,"")
$version="1.3"

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) LCMにより多頻度アイテム集合を列挙する
特徴) 1) 分類階層を扱うことが可能
      2) 頻出パターン, 飽和頻出パターン, 極大頻出パターンの３種類のパターンを列挙可能
      3) クラスを指定することで、上記3パターンに関する顕在パターン(emerging patterns)を列挙可能
書式) #{$cmd} i= [x=] [O=] [tid=] [item=] [taxo=] [class=] [type=] [s=|S=] [sx=|Sx=] [l=] [u=] [p=] [top=] [-replaceTaxo] [T=] [--help]

例) #{$cmd} i=basket.csv tid=traID item=商品

  ファイル名指定
  i= : アイテム集合データベースファイル名【必須】
  x= : taxonomyファイル名【オブション】*1
  O= : 出力ディレクトリ名【オプション:default:./take_現在日付時刻】

  項目名指定
  tid=   : トランザクションID項目名(i=上の項目名)【オプション:default="tid"】
  item=  : アイテム項目名(i=,t=上の項目名)【オプション:default="item"】
  class= : クラス項目名(i=上の項目名)【オプション:default="class"】
  taxo=  : 分類項目名を指定する(x=上の項目名)【条件付き必須:x=】

  列挙パラメータ
  type= : 抽出するパターンの型【オプション:default:F, F:頻出集合, C:飽和集合, M:極大集合】
  s=    : 最小支持度(全トランザクション数に対する割合による指定)【オプション:default:0.05, 0以上1以下の実数】
  S=    : 最小支持度(件数による指定)【オプション】
  sx=   : 最大支持度(support)【オプション:default:1.0, 0以上1以下の実数】
  Sx=   : 最大支持件数【オプション】
  l=    : パターンサイズの下限(1以上20以下の整数)【オプション:default:制限なし】
  u=    : パターンサイズの上限(1以上20以下の整数)【オプション:default:制限なし】
  p=    : 最小事後確率【オプション:default:0.5】
  g=    : 最小増加率【オプション】
  top=  : 列挙するパターン数の上限【オプション:default:制限なし】*2

  その他
  -replaceTaxo : taxonomyを置換する
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

  注釈
  *1 x=が指定されたとき、itemに対応するtaxonomyをトランザクションに追加して実行する。例えば、アイテムa,bのtaxonomyをX、c,dのtaxonomyをYとすると、あるトランザクションabdはabdXYとなる。
     ただし-replaceTaxoが指定されると、taxonomyは追加ではなく置換して実行する。前例ではトランザクションabdはXYに置換される。
  *2 top=が指定された時の動作: 例えばtop=10と指定すると、支持度が10番目高いパターンの支持度を最小支持度として頻出パターンを列挙する。よって、同じ支持度のパターンが複数個ある場合は10個以上のパターンが列挙されるかもしれない。

# より詳しい情報源 http://www.nysol.jp
# LCMの詳しい情報源 http://research.nii.ac.jp/~uno/codes-j.htm
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

args=MCMD::Margs.new(ARGV,"i=,x=,O=,tid=,item=,class=,taxo=,type=,s=,S=,sx=,Sx=,g=,p=,-uniform,l=,u=,top=,T=,-replaceTaxo,-q")

# コマンド実行可能確認
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD      , "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD_ZERO , "executable"))
#exit(1) unless(MCMD::chkCmdExe(TAKE::LcmIs::CMD_TRANS, "-v", "lcm_trans 1.0"))

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

idFN   = args.field("tid=",  iFile, "tid"  )
itemFN = args.field("item=", iFile, "item" )
clsFN  = args.field("class=",iFile, nil    )
taxoFN = args.field("taxo=", xFile, "taxo" )
idFN   = idFN["names"].join(",")   if idFN
itemFN = itemFN["names"].join(",") if itemFN
clsFN  = clsFN["names"].join(",")  if clsFN
taxoFN = taxoFN["names"].join(",") if taxoFN

sortInfo = args.bool("-q") 

eArgs=Hash.new
eArgs["type"   ] = args.  str("type=","F" )
eArgs["minSup" ] = args.float("s="   ,0.05 ,0  ,1      ) # 最小サポート
eArgs["minCnt" ] = args.  int("S="   ,nil  ,1  ,nil    ) # 最小サポート件数
eArgs["maxSup" ] = args.float("sx="  ,nil  ,0  ,1      ) # 最小サポート
eArgs["maxCnt" ] = args.  int("Sx="  ,nil  ,1  ,nil    ) # 最小サポート件数
eArgs["minProb"] = args.float("p="   ,0.5  ,0.5,1      ) # 最小事後確率
eArgs["minGR"  ] = args.float("g="   ,nil  ,1.0,nil    ) # 最小GR
eArgs["uniform"] = args. bool("-uniform") # クラス事前確率を一様と考えるかどうか
eArgs["minLen" ] = args.  int("l="   ,nil  ,1  ,nil    )
eArgs["maxLen" ] = args.  int("u="   ,nil  ,1  ,nil    )
eArgs["top"    ] = args.  int("top=" ,nil,0)

eArgs["nomodel"] = true

if ["F","C","M"].index(eArgs["type"]) == nil then
	raise "type= takes one of values: 'F', 'C', 'M'"
end

if eArgs["minLen"] and eArgs["maxLen"]
	if eArgs["minLen"] > eArgs["maxLen"] then
		raise "u= must be greater than or equal to l="
	end
end

if eArgs["type"]=="M" then
	eArgs["top"]=0
end

# V型DBの読み込み
db=TAKE::TraDB.new(iFile,idFN,itemFN,clsFN)

# taxonomyのセット
taxo=nil
if xFile!=nil then
	taxo=TAKE::Taxonomy.new(xFile,itemFN,taxoFN)
	if args.bool("-replaceTaxo") then
		db.repTaxo(taxo) # taxonomyの置換
	else
		db.addTaxo(taxo) # taxonomyの追加
	end
end

# パターン列挙
lcm=nil
if clsFN then
	lcm=TAKE::LcmEp.new(db);
	lcm.enumerate(eArgs)
else
	lcm=TAKE::LcmIs.new(db);
	lcm.enumerate(eArgs)
end

# 出力
system("mkdir -p #{outPath}")
lcm.output(outPath,sortInfo)

MCMD::msgLog("The final results are in the directory `#{outPath}'")

# 終了メッセージ
MCMD::endLog(args.cmdline)
