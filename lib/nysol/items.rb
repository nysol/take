#!/usr/bin/env ruby
require "rubygems"
require "nysol/mcmd"

require "nysol/taxonomy.rb"

module TAKE

#=アイテムクラス
# 頻出パターンマイニングで使われるアイテムを扱うクラス。
#
#===利用例
# 以下tra.csvの内容
# ---
# items
# a b c
# a c
# b
# c b d
#
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
# items=Items.new("tra.csv","items","item")
# puts items.file     # => ./1252810329_1850/dat/1
# puts items.itemFN   # => "item"
# puts items.idFN     # => "iid"
# puts items.size     # => 4
# puts items.taxonomy # =>nil
#
# taxo=Taxonomy.new("taxo.csv","item","taxo")
# items.addTaxo(taxo)
# puts items.file     # => ./1252810329_1850/dat/3
# puts items.itemFN   # => "item"
# puts items.idFN     # => "iid"
# puts items.size     # => 4
# p    items.taxonomy # => #<Taxonomy:0x1698eac @itemSize=4, @iFile="taxo.csv", @taxoFN="taxo", @itemFN="item", ...,@file="./1252810329_1850/dat/2">
#
#=====./1252810329_1850/dat/1 の内容
# item,iid
# a,1
# b,2
# c,3
# d,4
#
#=====./1252810329_1850/dat/3 の内容
# item,iid
# X1,5
# X2,6
# a,1
# b,2
# c,3
# d,4
#
class Items
	# itemsファイル (=>Mfile)
	attr_reader :file

	# アイテムの項目名(=>String)
	attr_reader :itemFN

	# id項目名(=>String)
	attr_reader :idFN

	# アイテムの種類数(=>Fixnum)
	attr_reader :size

	# 分類階層クラス(=>Taxonomy)
	attr_reader :taxonomy

private

	#==初期化
	#=====引数
	# iFile: アイテム項目を含むファイル名
	# itemFN: 新しいアイテム項目名
	# idFN: 連番によるアイテムidの項目名(デフォルト:"iid")
	#=====機能
	#* iFile上のアイテム項目(@itemFN)からアイテム(@itemFN)と連番("num")の2項目からなるファイルを生成する。
	#* itemFN項目の値としては、スペースで区切られた複数のアイテムであってもよい。
	#* 同じアイテムが重複して登録されていれば単一化される。
	#* アイテム順にソートされる。
	#* アイテムの件数(種類数)がセットされる。
	def initialize(iFile,itemFN,idFN="__iid")
		@temp=MCMD::Mtemp.new

		@iFile   = Array.new
		@iPath   = Array.new
		@iFile.push(iFile)
		@iPath.push(File.expand_path(iFile))
		@taxonomy = nil
		@file     = @temp.file  # 出力ファイル名
		@itemFN=itemFN
		@idFN=idFN

		f=""
		f << "mcut    f=#{itemFN}   i=#{iFile} |"
		f << "msortf  f=#{itemFN}   |"
		f << "muniq   k=#{itemFN}   |"
		f << "mnumber s=#{itemFN} a=#{idFN} S=0 o=#{@file}"
		system(f)

		@size = MCMD::mrecount("i=#{@file}") # itemの数

	end

public

	def show
		puts "#### BEGIN Items class"
		puts "@temp=#{@temp}"
		puts "@iFile=#{@iFile}"
		puts "@iPath=#{@iPath}"
		puts "@taxonomy=#{@taxonomy}"
		puts "@itemFN=#{@itemFN}"
		puts "@idFN=#{@idFN}"
		puts "@file=#{@file}"
		puts "@file:"
		system("cat #{@file}")
		puts "#### END Items class"
	end

	#==アイテムの追加
	# iFileのitemFN項目をアイテムとして追加する。
	#=====引数
	# iFile: アイテム項目を含むファイル名
	# itemFN: iFile上のアイテム項目名
	#=====機能
	#* itemFNとしては、スペースで区切られた複数のアイテムであってもよい。
	#* 同じアイテムが重複していれば単一化される。
	#* 追加後アイテム順にソートされる。
	#* アイテム数が更新される。
	def add(iFile,itemFN)

		@iFile.push(iFile)
		@iPath.push(File.expand_path(iFile))

		xx=MCMD::Mtemp.new
		xx1=xx.file
		xx2=xx.file
		f=""
		f << "msortf  f=#{@itemFN}            i=#{iFile} |"
		f << "mcommon k=#{@itemFN} m=#{@file} |"
		f << "mcut    f=#{itemFN}:#{@itemFN}  |"
		f << "msortf  f=#{@itemFN}            |"
		f << "muniq   k=#{@itemFN}            |"
		f << "mnumber s=#{@itemFN} S=#{@size+1} a=#{@idFN} o=#{xx1}"
		system(f)

		f=""
		f << "mcat                            i=#{@file},#{xx1} |"
		f << "msortf  f=#{@itemFN}            o=#{xx2}"
		system(f)

		# 新itemファイル登録&item数更新
		FileUtils.mv(xx2,@file)
		@size = MCMD::mrecount("i=#{@file}")

	end

	#==Taxonomyの設定
	# Taxonomy(分類階層)を設定する。
	#=====引数
	# taxo: taxonomy オブジェクト
	#=====機能
	#* Taxonomyオブジェクトをメンバとして追加する。
	#* 分類項目をアイテムとして追加する。
  def addTaxo(taxo)

		@taxonomy=taxo
		
		add(@taxonomy.file,@taxonomy.taxoFN) # taxonomyをアイテムとして追加登録

	end

  def repTaxo(taxo)

		#@taxonomy=taxo #replaceの場合はtaxonomyを登録しない

		@file = @temp.file # 出力ファイル名
		f=""
		f << "mcut    f=#{taxo.taxoFN}:#{@itemFN} i=#{taxo.file} |"
		f << "msortf  f=#{@itemFN}                |"
		f << "muniq   k=#{@itemFN}                |"
		f << "mnumber s=#{@itemFN} a=#{@idFN} S=1              o=#{@file}"
		system(f)

	end

end

end # module
