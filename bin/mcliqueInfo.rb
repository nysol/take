#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# ver="1.0" # 初期リリース 2014/2/20
$cmd=$0.sub(/.*\//,"")
$version=1.0

def help
STDERR.puts <<EOF
----------------------------
#{$cmd} version #{$version}
----------------------------
概要) クリークデータから、クリーク別に参照グラフとの枝の違いを計算する。
書式) #{$cmd} i= [id=] [f=] [o=] [T=] [--help]

  ファイル名指定
  i=     : クリークデータファイル名
	id=    : クリークID項目名(デフォルト: "id")
  f=     : クリークを構成する節点項目名(デフォルト: "node")
	o=     : 出力ファイル名

  その他
  T= : ワークディレクトリ(default:/tmp)
  --help : ヘルプの表示

入力データ)
クリークIDと節点の2項目からなるCSVファイル。
mclique.rb コマンドで-nodeを指定して出力されるデータファイル。

出力データ1)
クリーク別に以下の項目を出力する。
nSize: クリークを構成するnode数
eSize: クリークを構成する枝数(nSize(nSize-1)/2)
extNodes: 外部接続節点数
extEdges: 外部接続枝数
extCliques: 外部接続クリーク数

出力データ2)
ノード別に以下の項目を出力する。
degree: 次数(接続節点数)
cliques: 所属するクリーク数
size: 所属する最大クリークサイズ-最小クリークサイズ

例)

# Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
	STDERR.puts "version #{$version}"
	exit
end

help() if ARGV[0]=="--help" or ARGV.size <= 0
ver() if ARGV[0]=="--version"

args=MCMD::Margs.new(ARGV,"i=,id=,f=,o=,T=","i=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

iFile = args.file("i=","r") # i=
oFile = args.file("o=","w") # o=

## id=
id=args.field("id=",iFile,"id")["names"][0] # id項目名

## f=
node = args.field("f=", iFile, "node",1,1)["names"][0] 

wf=MCMD::Mtemp.new
xxid_node=wf.file
xxnSize=wf.file
xxedge=wf.file

# i=のサンプル
# id,node
# 0,a
# 0,b
# 0,c
# 0,d
# 1,d
# 1,e
# 1,f
# 2,e
# 2,f
# 2,g
# 3,e
# 3,f
# 3,h

# nodeマスタ
f=""
f << "mcut   f=#{id}:__id,#{node}:node i=#{iFile} |"
f << "msortf f=__id,node |"
f << "muniq  k=__id,node o=#{xxid_node}"
system(f)

# nSize: クリーク別接点数、枝数のカウント
f=""
f << "mcount k=__id a=nSize i=#{xxid_node} |"
f << "mcal   c='${nSize}*(${nSize}-1)/2' a=eSize o=#{xxnSize}"
system(f)

# edgeマスタ
f=""
f << "mcombi k=__id f=node n=2 -p a=node1,node2 i=#{xxid_node} |"
f << "mcut   f=node -r |"
f << "msortf f=node1,node2,__id o=#{xxedge}"
system(f)

xxextLink=wf.file
xxextNodes=wf.file
xxextEdges=wf.file
xxextCliques=wf.file

# xxid_node xxedge            xxextLin
# __id,node __id,node1,node2  __id,node,node2,__id2
# 0,a       0,a,b             0,d,e,1
# 0,b       0,a,c             0,d,f,1
# 0,c       0,a,d             1,d,a,0
# 0,d       0,b,a             1,d,b,0
# 1,d       0,b,c             1,d,c,0
# 1,e       0,b,d             1,e,g,2
# 1,f       0,c,a             1,f,g,2
# 2,e       0,c,b             1,e,h,3
# 2,f       0,c,d             1,f,h,3
# 2,g       0,d,a             2,f,d,1
# 3,e       0,d,b             2,e,d,1
# 3,f       0,d,c             2,e,h,3
# 3,h       1,d,e             2,f,h,3
#           1,d,f             3,e,d,1
#           1,e,d             3,f,d,1
#           1,e,f             3,f,g,2
#           2,e,f             3,e,g,2
#           3,e,f
#           2,e,g
#           3,e,h
#           1,f,d
#           1,f,e
#           2,f,e
#           3,f,e
#           2,f,g
#           3,f,h
#           2,g,e
#           2,g,f
#           3,h,e
#           3,h,f
f=""
f << "msortf f=node i=#{xxid_node} |"
f << "mnjoin k=node m=#{xxedge} K=node1 f=node2,__id:__id2 |"            # クリークの節点から接続されている節点を全て結合
f << "msel c='${__id}!=${__id2}' |"                                      # 結合された節点が元のクリークと同じものは削除
f << "msortf  f=__id,node2 |"
f << "mcommon k=__id,node2 K=__id,node m=#{xxid_node} -r o=#{xxextLink}" # remove the nodes included in the same clique
system(f)

# 外部接続節点本数
f=""
f << "mcut    f=__id,node2 i=#{xxextLink} |"
f << "msortf  f=__id,node2 |"
f << "muniq   k=__id,node2 |"
f << "mcount k=__id a=extNodes o=#{xxextNodes}"
system(f)

# 外部接続枝本数
f=""
f << "mcut   f=__id i=#{xxextLink} |"
f << "msortf f=__id |"
f << "mcount k=__id a=extEdges o=#{xxextEdges}"
system(f)

# 外部接続クリーク数
f=""
f << "msortf f=__id,__id2 i=#{xxextLink} |"
f << "muniq  k=__id,__id2 |"
f << "mcut   f=__id |"
f << "msortf f=__id |"
f << "mcount k=__id a=extCliques o=#{xxextCliques}"
system(f)

# 全項目結合
f=""
f << "mcut  f=__id,nSize,eSize                    i=#{xxnSize} |"
f << "mjoin k=__id m=#{xxextNodes}   f=extNodes   -n |"
f << "mjoin k=__id m=#{xxextEdges}   f=extEdges   -n |"
f << "mjoin k=__id m=#{xxextCliques} f=extCliques -n |"
f << "mnullto f=* v=0 |"
f << "mfldname f=__id:#{id} o=#{oFile}"
system(f)

# 終了メッセージ
MCMD::endLog(args.cmdline)

