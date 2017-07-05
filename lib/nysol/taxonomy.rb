#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

module TAKE

#=分類階層(taxonomy)クラス
# 一階層の分類階層(アイテム-分類)を扱うクラス。
#
#===利用例
# 以下taxo.csvの内容
# ---
# item,taxo
# a,X1
# b,X1
# c,X2
# d,X2
#
# 以下rubyスクリプト
# ---
# require 'rubygems'
# require 'mining'
# taxo=Taxonomy("taxo.csv","item","taxo")
# puts taxo.itemFN   # => "item"
# puts taxo.taxoFN   # => "taxo"
# puts taxo.itemSize # => 4 (アイテムは"a,b,c,d"の4種類)
# puts taxo.taxoSize # => 2 (分類は"X1,X2"の2種類)
# puts taxo.file     # => ./1252379737_1756/dat/1
#
#=====./1252379737_1756/dat/1 の内容
# item,taxo
# a,X1
# b,X1
# c,X2
# d,X2
class Taxonomy
	# アイテムの項目名(=>String)
	attr_reader :itemFN

	# 分類の項目名(=>String)
	attr_reader :taxoFN

	# アイテムの種類数(=>Fixnum)
	attr_reader :itemSize

	# 分類の種類数(=>Fixnum)
	attr_reader :taxoSize

	# taxonomyデータファイル名(=>String)
	attr_reader :file

	#=== taxonomyクラスの初期化
	# 一階層の分類階層を扱う。
	# アイテム項目とその分類名項目を持つファイルから分類階層オブジェクトを生成する。
	#====引数
	# iFile: taxonomyファイル名
	# itemFN: アイテム項目名
	# taxoFN: 分類項目名
	#====機能
	#* アイテム(itemFN)と分類(taxoFN)の2項目からなるファイルが規定のパス(Taxonomy.file)に書き出される。
	#* 同じアイテムが重複して登録されていれば単一化して書き出される。
	#* アイテム順にソートされる。
	#* アイテム数と分類数を計算する。
	def initialize(iFile,itemFN,taxoFN)
		@temp=MCMD::Mtemp.new

		@iFile  = iFile
		@iPath  = File.expand_path(@iFile)
		@itemFN  = itemFN
		@taxoFN  = taxoFN

		# item順に並べ替えてpathに書き出す
		@file=@temp.file
		f=""
		f << "mcut   f=#{@itemFN},#{@taxoFN} i=#{@iFile} |"
		f << "msortf f=#{@itemFN},#{@taxoFN} |"
		f << "muniq  k=#{@itemFN},#{@taxoFN} o=#{@file}"
		system(f)

		# oFileに登録されているitemの数をカウントする
		tf=MCMD::Mtemp.new
		xx1=tf.file
		f=""
		f << "mcut    f=#{@itemFN}                    i=#{iFile} |"
		f << "mtrafld f=#{@itemFN}   a=__fld -valOnly |"
		f << "mtra    f=__fld   -r                    |"
		f << "msortf  f=__fld                         |"
		f << "muniq   k=__fld                         |"
		f << "mcount  a=size                          |"
		f << "mcut    f=size   -nfno                  o=#{xx1}"
    system(f)
    tbl=MCMD::Mtable.new("i=#{xx1} -nfn")
    @itemSize = tbl.cell(0,0).to_i

		# oFileに登録されているtaxonomyの数をカウントする
		xx2=tf.file
		f=""
		f << "mcut   f=#{@taxoFN}:item i=#{@file} |"
		f << "msortf f=item            |"
		f << "muniq  k=item            |"
		f << "mcount a=size            |"
		f << "mcut   f=size   -nfno    o=#{xx2}"
    system(f)
    tbl=MCMD::Mtable.new("i=#{xx2} -nfn")
    @taxoSize = tbl.cell(0,0).to_i
	end

end

end #module

