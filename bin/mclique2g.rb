#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# ver="1.0" # 初期リリース 2014/7/04
$cmd=$0.sub(/.*\//,"")
$version=1.0

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) クリークを一つの節点に変換し新たなグラフを構成する。
書式) #{$cmd} i= [id=] [f=] eo= no= [T=] [--help]

  ファイル名指定
  i=  : クリークファイル名
	id= : クリークID項目名(デフォルト:"id")
  f=  : クリークを構成する節点項目名(デフォルト:"node")
  eo= : 枝ファイル名
  no= : 節点ファイル名

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力データ)
クリークIDと節点の2項目からなるCSVファイル。
これはmclique.rbコマンドでのno=に出力されるデータに対応する。

出力データ)
eo=には枝(節点ペア)データ、no=には節点データが、以下の項目で出力される。
eo=: node1,node2,weight
  node1,node2: 入力データのクリークIDを節点番号とする枝データ。
  weight: 2つのクリークの共通節点数。
no=: node,weight
  node: 入力データのクリークIDを節点番号とする枝データ。
  weight: クリークを構成していた節点数。

例)

# Copyright(c) NYSOL 2014- All Rights Reserved.
EOF
exit
end

def ver()
	STDERR.puts "version #{$version}"
	exit
end

help() if ARGV[0]=="--help" or ARGV.size <= 0
ver() if ARGV[0]=="--version"

args=MCMD::Margs.new(ARGV,"i=,id=,f=,eo=,no=,T=","i=,eo=,no=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

iFile = args.file("i=" ,"r") # i=
eoFile = args.file("eo=","w") # eo=
noFile = args.file("no=","w") # no=

## id=
id=args.field("id=",iFile,"id",1,1)["names"][0]

## f=
node = args.field("f=", iFile, "node", 1, 1)["names"][0]

wf=MCMD::Mtemp.new
xxbase=wf.file

# cleaning
f=""
f << "mcut   f=#{id},#{node} i=#{iFile} |"
f << "msortf f=#{id},#{node} |"
f << "muniq  k=#{id},#{node} o=#{xxbase}"
system(f)

f=""
f << "mcut f=#{id}:node i=#{xxbase} |"
f << "msortf f=node |"
f << "mcount k=node a=weight o=#{noFile}"
system(f)

f=""
f << "msortf f=#{node} i=#{xxbase} |"
f << "mcombi k=#{node} f=#{id} n=2 a=node1,node2 |"
f << "mfsort f=node1,node2 |"
f << "msortf f=node1,node2 |"
f << "mcount k=node1,node2 a=weight |"
f << "mcut   f=node1,node2,weight o=#{eoFile}"
system(f)

# end message
MCMD::endLog(args.cmdline)

