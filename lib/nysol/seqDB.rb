#!/usr/bin/env ruby
require "rubygems"
require "nysol/mcmd"

require "nysol/items"

module TAKE

#=トランザクションデータクラス
# 頻出パターンマイニングで使われるトランザクションデータを扱うクラス。
# トランザクションファイルは、トランザクションID項目とアイテム集合項目から構成される。
# アイテム集合は、スペースで区切られた文字列集合として表現される。
#
#===利用例
# 以下tra.csvの内容
# ---
# items
# a b d
# a d e
# c e
# a d
# c d e
# c e
# a d e
#
# 以下taxo.csvの内容
# ---
# item,taxo
# a,X1
# b,X1
# c,X2
# d,X2
# e,X2
#
# 以下rubyスクリプト
# ---
# require 'rubygems'
# require 'mining'
#
# tra=SeqDB.new("tra.csv",nil,"items")
# puts tra.file       # => ./1252813069_2179/dat/1
# puts tra.numTraFile # => nil
# puts tra.idFN       # => tid
# puts tra.itemsetFN  # => items
# puts tra.recCnt     # => 7
# p    tra.items      # => #<Items:0x16a39ec @iItemFN=["items"],...
#
# taxo=Taxonomy.new("taxo.csv","item","taxo")
# tra.addTaxo(taxo)
# tra.mkNumTra
# puts tra.numTraFile #=> ./1252813069_2179/dat/6
# p    tra.items      #=> #<Items:0x16a39ec @iItemFN=["items", "taxo"],..., @taxonomy=#<Taxonomy:0x168ba7c ...
#
#=====./1252813069_2179/dat/1 の内容
# tid,items
# 1,a b d
# 2,a d e
# 3,c e
# 4,a d
# 5,c d e
# 6,c e
# 7,a d e
#
#=====./1252813069_2179/dat/6 の内容
# 1 2 3 4 5 6 7
# 1 2 4 6 7
# 1 4 5 6 7
# 3 5 7
# 1 4 6 7
# 3 4 5 7
# 3 5 7
# 1 4 5 6 7
#
class SeqDB
	attr_reader :file           # トランザクションファイル名
	attr_reader :idFN           # トランザクションID項目名(String)
	attr_reader :timeFN         # 時間項目名(String)
	attr_reader :itemFN         # アイテム集合項目名(String)
	attr_reader :clsFN          # クラス項目名(String)
	attr_reader :size           # トランザクションサイズ(Num)
	attr_reader :items          # Itemsクラス
	attr_reader :taxonomy       # 階層分類クラス
	attr_reader :clsNameRecSize # クラス別件数
	attr_reader :clsSize        # クラス数
	attr_reader :cFile          # クラスファイル

private

	#=== SeqDBクラスの初期化
	#
	#====引数
	# iFile: transactionファイル名
	# iItemsetFN: iFile上のアイテム集合項目名
	# idFN: 新しく命名するトランザクションID項目名
	# itemsetFN: 新しく命名するアイテム集合項目名
	#
	#====機能
	#* トランザクションIDとアイテム集合の2項目から構成するトランザクションデータを新たに作成する。
	#* ID項目が指定されていなければ、1から始まる連番によってID項目を新規に作成する。
	#* トランザクション件数(iFileのレコード件数)を計算する。
	#* アイテム集合項目からItemsオブジェクトを生成する。
	def initialize(iFile,idFN,timeFN,itemFN,padding,clsFN=nil)
		@temp=MCMD::Mtemp.new

		@iFile  = iFile                    # 入力ファイル
		@iPath  = File.expand_path(@iFile) # フルパス
		@idFN   = idFN                     # トランザクションID項目名
		@timeFN = timeFN                   # 時間項目名
		@itemFN = itemFN                   # アイテム項目名
		@file   = @temp.file               # 出力ファイル名
		@padding= padding                  # 時系列パディング

		# padding指定の場合は、asciiコードの先頭文字列を挿入
		f=""
		if @padding then
			f << "mcut     f=#{@idFN},#{@timeFN},#{@itemFN} i=#{@iFile} |"
			f << "msortf   f=#{@idFN},#{@timeFN}%n,#{@itemFN} |"
			f << "muniq    k=#{@idFN},#{@timeFN},#{@itemFN}   |"
			f << "mpadding k=#{@idFN} f=#{@timeFN}%n v=! o=#{@file}"
		else
			f << "mcut     f=#{@idFN},#{@timeFN},#{@itemFN} i=#{@iFile} |"
			f << "msortf   f=#{@idFN},#{@timeFN}%n,#{@itemFN} |"
			f << "muniq    k=#{@idFN},#{@timeFN},#{@itemFN} o=#{@file}"
		end
		system(f)

		# レコード数の計算
		#@recCnt = MCMD::mrecount("i=#{@file}")

		# トランザクション数の計算
		tf=MCMD::Mtemp.new
		xx1=tf.file
		f=""
		f << "mcut   f=#{@idFN} i=#{@file} |"
		f << "muniq  k=#{@idFN} |"
		f << "mcount a=__cnt    o=#{xx1}"
		system(f)
    tbl=MCMD::Mtable.new("i=#{xx1}")
		num=tbl.name2num()["__cnt"]
    @size = tbl.cell(num,0).to_i

		# トランザクションデータからアイテムオブジェクトを生成
		if @padding then
			# paddingの場合は、特殊アイテム(!)を0番とし、出力を制御する。
			@items=TAKE::Items.new(@file,@itemFN)
		else
			@items=TAKE::Items.new(@file,@itemFN)
		end

		# クラスデータ
		if clsFN then
			@clsFN=clsFN
			@cFile=@temp.file

			# tid-クラス項目名ファイルの生成
			xx1=@temp.file
			f=""
			f << "mcut   f=#{@idFN},#{@clsFN} i=#{@iFile} |"
			f << "msortf f=#{@idFN},#{@clsFN} |"
			f << "muniq  k=#{@idFN},#{@clsFN} o=#{@cFile}"
			system(f)

			f=""
			f << "mcut   f=#{@clsFN}         i=#{@cFile} |"
			f << "msortf f=#{@clsFN}         |"
			f << "mcount k=#{@clsFN} a=count o=#{xx1}"
			system(f)

			# クラス数
			@clsSize = MCMD::mrecount("i=#{xx1}")

			# 文字列としてのクラス別件数配列を数値配列に変換する
			@clsNames = []
			@clsNameRecSize = {}
			MCMD::Mcsvin.new("i=#{xx1}"){|csv|
				csv.each{|fldVal|
					@clsNames << fldVal[csv.names[0]]
					@clsNameRecSize[fldVal[csv.names[0]]]=fldVal[csv.names[1]].to_i
				}
			}
		end

	end

public
	def show()
		puts "#### BEGIN SeqDB class"
		puts "@temp=#{@temp}"
		puts "@iFile=#{@iFile}"
		puts "@iPath=#{@iPath}"
		puts "@idFN=#{@idFN}"
		puts "@timeFN=#{@timeFN}"
		puts "@itemFN=#{@itemFN}"
		puts "@padding=#{@padding}"
		puts "@file=#{@file}"
		@items.show
		system("head #{@file}")
		puts "#### END SeqDB class"
	end

	def replaceFile(train)

		@file   = train

		# レコード数の計算
		#@recCnt = MCMD::mrecount("i=#{@file}")

		# トランザクション数の計算
		tf=MCMD::Mtemp.new
		xx1=tf.file
		f=""
		f << "mcut   f=#{@idFN} i=#{@file} |"
		f << "muniq  k=#{@idFN} |"
		f << "mcount a=__cnt    o=#{xx1}"
		system(f)
    tbl=MCMD::Mtable.new("i=#{xx1}")
		num=tbl.name2num()["__cnt"]
    @size = tbl.cell(num,0).to_i

	end


	#=== taxonomyをトランザクションに追加
	# トランザクションデータのアイテム集合に、対応するtaxonomyを追加する。
	#
	#====引数
	# taxonomy: Taxonomyオブジェクト。
	#
	#====機能
	#* トランザクションデータのアイテム集合項目におけるアイテム全てについて、対応するtaxonomyをアイテム集合として追加する。
	def repTaxo(taxonomy)

		#@taxonomy=taxonomy

		@items.repTaxo(taxonomy) # アイテムクラスをtaxonomyで置換する

		tFile =taxonomy.file
		itemFN=taxonomy.itemFN
		taxoFN=taxonomy.taxoFN

		tf=MCMD::Mtemp.new
		xx1=tf.file
		f=""
		f << "msortf f=#{@itemFN}                                    i=#{@file} |"
		f << "mjoin  k=#{@itemFN} K=#{itemFN} f=#{taxoFN} m=#{tFile} |"
		f << "mcut   f=#{@idFN},#{@timeFN},#{taxoFN}:#{@itemFN}      |"
		f << "msortf f=#{@idFN},#{@timeFN},#{@itemFN}                o=#{xx1}"
		system(f)

		@file=@temp.file
		FileUtils.mv(xx1,@file)

	end
end

end # module
