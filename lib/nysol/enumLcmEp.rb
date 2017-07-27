#!/usr/bin/env ruby
require "rubygems"
require "nysol/mcmd"
require "nysol/take"

require "nysol/traDB.rb"

module TAKE

#========================================================================
# 列挙関数:lcm 利用DB:TraDB
#========================================================================
class LcmEp
	attr_reader :size  # 列挙されたパターン数
	attr_reader :pFile
	attr_reader :tFile

	@@intMax=2147483646
	#@@intMax=100

	# posトランザクションの重み計算
	# マニュアルの式(10)
	def calOmega(posCnt)
		return @@intMax/posCnt
	end

	# LCM最小サポートの計算
	# マニュアルの式(9)
	def calSigma(minPos,minGR,posCnt,negCnt)
		omegaF=@@intMax.to_f/posCnt.to_f
		beta=minPos
		w=posCnt.to_f/negCnt.to_f
#puts "omegaF=#{omegaF}"
#puts "minPos=#{minPos}"
#puts "beta=#{beta}"
#puts "posCnt=#{posCnt}"
#puts "negCnt=#{negCnt}"
#puts "w=#{w}"
		sigma=(beta*(omegaF-w/minGR)).to_i  # 切り捨て
		sigma=1 if sigma<=0
		return sigma
	end

	def reduceTaxo(pat,items)
		tf=MCMD::Mtemp.new

		if items.taxonomy==nil then
			return pat
		end

		xxrt = tf.file
		taxo=items.taxonomy
		f=""
		f << "mtrafld f=#{taxo.itemFN},#{taxo.taxoFN} -valOnly a=__fld i=#{taxo.file} o=#{xxrt}"
		system(f)

		# xxrtの内容：oyakoに親子関係にあるアイテム集合のリストが格納される
		# __fld
		# A X
		# B X
		# C Y
		# D Z
		# E Z
		# F Z
		oyako=ZDD.constant(0)
		MCMD::Mcsvin.new("i=#{xxrt}"){|csv|
			csv.each{|fldVal|
				items=fldVal["__fld"]
				oyako=oyako+ZDD.itemset(items)
			}
		}

		# 親子リストにあるアイテム集合を含むパターンを削除する
		pat=pat.restrict(oyako).iif(0,pat)

		return pat
	end

	def initialize(db,outtf=true)
		@temp=MCMD::Mtemp.new
		@db      = db         # 入力データベース
		@file=@temp.file
		items=@db.items
		@outtf = outtf

		# 重みファイルの作成
		# pos,negのTransactionオブジェクトに対してLCMが扱う整数アイテムによるトランザクションファイルを生成する。
		# この時、pos,negを併合して一つのファイルとして作成され(@wNumTraFile)、
		# 重みファイル(@weightFile[クラス])の作成は以下の通り。
		# 1.対象クラスをpos、その他のクラスをnegとする。
		# 2. negの重みは-1に設定し、posの重みはcalOmegaで計算した値。
		# 3.@wNumTraFileの各行のクラスに対応した重みデータを出力する(１項目のみのデータ)。
		@weightFile = Hash.new
		@posWeight  = Hash.new
		@sigma      = Hash.new
		@db.clsNameRecSize.each {|cName,posSize|
			@weightFile[cName] = @temp.file
			@posWeight[cName]=calOmega(posSize)

			f=""
			f << "mcut    -nfno f=#{@db.clsFN}                           i=#{@db.cFile} |"
			f << "mchgstr -nfn  f=0 c=#{cName}:#{@posWeight[cName]} O=-1 o=#{@weightFile[cName]}"
			system(f)
		}

		# アイテムをシンボルから番号に変換する。
		f=""
		f << "msortf f=#{@db.itemFN}                                                   i=#{@db.file} |"
		f << "mjoin  k=#{@db.itemFN} K=#{items.itemFN} m=#{items.file} f=#{items.idFN} |"
		f << "mcut   f=#{@db.idFN},#{items.idFN}                                       |"
		f << "msortf f=#{@db.idFN}                                                     |"
		f << "mtra   k=#{@db.idFN} f=#{items.idFN}                                     |"
		f << "mcut   f=#{items.idFN} -nfno                                             o=#{@file}"
		system(f)
	end

	# 各種パラメータを与えて列挙を実行
  def enumerate(eArgs)

		pFiles=[]
		tFiles=[]
		tf=MCMD::Mtemp.new
		@db.clsNameRecSize.each{|cName,posSize|
			negSize=@db.size-posSize

			# minGRの計算
			if eArgs["minGR"] then
				@minGR=eArgs["minGR"]
			else
				minProb=0.5
				minProb=eArgs["minProb"] if eArgs["minProb"]
				if eArgs["uniform"] then
					@minGR = (minProb/(1-minProb)) * (@db.clsSize-1) # マニュアルの式(4)
				else
					@minGR = (minProb/(1-minProb)) * (negSize.to_f/posSize.to_f) # マニュアルの式(4)
				end
			end

			# 最小サポートと最小サポート件数
			# s=0.05
			# s=c1:0.05,c2:0.06
			# S=10
			# S=c1:10,c2:15
			if eArgs["minCnt"] then
				if eArgs["minCnt"].class.name=="Hash"
					@minPos = eArgs["minCnt"][cName]
				else
					@minPos = eArgs["minCnt"]
				end
			else
				if eArgs["minSup"].class.name=="Hash"
					@minPos = (eArgs["minSup"][cName] * posSize.to_f + 0.99).to_i
				else
					@minPos = (eArgs["minSup"] * posSize.to_f + 0.99).to_i
				end
			end

			# 最大サポートと最大サポート件数
			if eArgs["maxCnt"] then
				if eArgs["maxCnt"].class.name=="Hash"
					@maxPos = eArgs["maxCnt"][cName]
				else
					@maxPos = eArgs["maxCnt"]
				end
			elsif eArgs["maxSup"]
				if eArgs["maxSup"].class.name=="Hash"
					@maxPos = (eArgs["maxSup"][cName] * posSize.to_f + 0.99).to_i
				else
					p posSize
					@maxPos = (eArgs["maxSup"] * posSize.to_f + 0.99).to_i
				end
			else
				@maxPos = posSize.to_f
			end

			@sigma[cName] = calSigma(@minPos,@minGR,posSize,negSize)

			# lcmのパラメータ設定と実行
			lcmout = tf.file # lcm出力ファイル
			# 頻出パターンがなかった場合、lcm出力ファイルが生成されないので
			# そのときのために空ファイルを生成しておいく。
			system("touch #{lcmout}")

			run=""
			run << "#{eArgs["type"]}IA"
			run << " -U #{@maxCnt}"         if @maxCnt # windowサイズ上限
			run << " -l #{eArgs['minLen']}" if eArgs["minLen"] # パターンサイズ下限
			run << " -u #{eArgs['maxLen']}" if eArgs['maxLen'] # パターンサイズ上限
			run << " -w #{@weightFile[cName]} #{@file} #{@sigma[cName]} #{lcmout}"

			
			# lcm実行
			MCMD::msgLog("#{run}")
			TAKE::run_lcm(run)
			#system run

#system("cp #{@file} xxtra_#{cName}")
#system("cp #{@weightFile[cName]} xxw_#{cName}")
#system("echo '#{run}' >xxscp_#{cName}")
			# パターンのサポートを計算しCSV出力する
			MCMD::msgLog("output patterns to CSV file ...")
			pFiles << @temp.file

			transle = @temp.file
			TAKE::run_lcmtrans(lcmout,"e",transle)

			f=""
			#f << "lcm_trans #{lcmout} e |" # pattern,countP,countN,size,pid
			f << "mdelnull f=pattern i=#{transle}                            |"
			f << "mcal     c='round(${countN},1)' a=neg                      |"
			f << "mcal     c='round(${countP}/#{@posWeight[cName]},1)' a=pos |"
			f << "mdelnull f=pattern                                         |"
			f << "msetstr  v=#{cName} a=class                                |"
			f << "msetstr  v=#{posSize} a=posTotal                           |"
			f << "msetstr  v=#{@minGR} a=minGR                           |"
			f << "mcut     f=class,pid,pattern,size,pos,neg,posTotal,minGR         o=#{pFiles.last}"
			system(f)

			s = MCMD::mrecount("i=#{pFiles.last}") # 列挙されたパターンの数
			MCMD::msgLog("the number of contrast patterns on class `#{cName}' enumerated is #{s}")

			if @outtf then
				# トランザクション毎に出現するパターンを書き出す
				MCMD::msgLog("output tid-patterns ...")
				tFiles << @temp.file

				xxw= tf.file
				f=""
				f << "mcut    f=#{@db.idFN}                  i=#{@db.file} |"
				f << "muniq   k=#{@db.idFN}                  |"
				f << "mnumber S=0 a=__tid -q                 |"
				f << "msortf  f=__tid                        o=#{xxw};"
				system(f)

				translt = @temp.file
				TAKE::run_lcmtrans(lcmout,"t",translt)

				f=""
				#f << "lcm_trans #{lcmout} t |" #__tid,pid
				f << "msortf   f=__tid i=#{translt}           |"
				f << "mjoin    k=__tid m=#{xxw} f=#{@db.idFN} |"
				f << "msetstr  v=#{cName} a=class             |"
				f << "mcut     f=#{@db.idFN},class,pid        o=#{tFiles.last}"
				system(f)
			end
		}

		# クラス別のパターンとtid-pidファイルを統合して最終出力
		@pFile = @temp.file
		@tFile = @temp.file

		# パターンファイル併合
		xxpCat = tf.file
		f=""
		f << "mcat                i=#{pFiles.join(",")} |"
		f << "msortf  f=class,pid |"
		f << "mnumber s=class,pid S=0 a=ppid  o=#{xxpCat}"
		system(f)

		# パターンファイル計算
		items=@db.items
		f=""
		f << "mcut    f=class,ppid:pid,pattern,size,pos,neg,posTotal,minGR           i=#{xxpCat} |"
		f << "msetstr v=#{@db.size} a=total                                                      |" # トータル件数
		f << "mcal    c='${total}-${posTotal}' a=negTotal                                        |" # negのトータル件数
		f << "mcal    c='${pos}/${posTotal}' a=support                                           |" # サポートの計算
  	f << "mcal    c='if(${neg}==0,1.797693135e+308,(${pos}/${posTotal})/(${neg}/${negTotal}))' a=growthRate |"

		if eArgs["uniform"] then
			f << "mcal  c='(${pos}/${posTotal})/(${pos}/${posTotal}+(#{@db.clsSize}-1)*${neg}/${negTotal})' a=postProb |"
		else
			f << "mcal  c='${pos}/(${pos}+${neg})' a=postProb |"
		end
		f << "msel    c='${pos}>=#{@minPos}&&${growthRate}>=${minGR}'                 |" # minSupとminGRによる選択
		f << "mvreplace vf=pattern m=#{items.file} K=#{items.idFN} f=#{items.itemFN} |"
		f << "mcut    f=class,pid,pattern,size,pos,neg,posTotal,negTotal,total,support,growthRate,postProb |"
		f << "mvsort  vf=pattern |"
		f << "msortf  f=class%nr,postProb%nr,pos%nr                                                   o=#{@pFile}"
		system(f)

		# アイテムを包含している冗長なタクソノミを削除
		if items.taxonomy then
			MCMD::msgLog("reducing redundant rules in terms of taxonomy ...")
			zdd=ZDD.constant(0)
			MCMD::Mcsvin.new("i=#{@pFile}"){|csv|
				csv.each{|fldVal|
					pat=fldVal['pattern']
					zdd=zdd+ZDD.itemset(pat)
				}
			}
			zdd=reduceTaxo(zdd,@db.items)

			xxp1=tf.file
			xxp2=tf.file
			xxp3=tf.file
			zdd.csvout(xxp1)

			f=""
			f << "mcut   -nfni f=1:pattern i=#{xxp1} |"
			f << "mvsort vf=pattern        |"
			f << "msortf f=pattern         o=#{xxp2}"
			system(f)

			f=""
			f << "msortf  f=pattern           i=#{@pFile} |"
			f << "mcommon k=pattern m=#{xxp2} |"
			f << "msortf  f=class%nr,postProb%nr,pos%nr o=#{xxp3}"
			system(f)
			system "mv #{xxp3} #{@pFile}"
		end

		# 列挙されたパターンを含むtraのみ選択するためのマスタ
		xxp4=tf.file
		f=""
		f << "mcut    f=class,pid i=#{@pFile} |"
		f << "msortf  f=class,pid o=#{xxp4}"
		system(f)

		if @outtf then
			# tid-pidファイル計算
			f=""
			f << "mcat                                       i=#{tFiles.join(",")} |"
			f << "msortf  f=class,pid                        |"
			f << "mjoin   k=class,pid m=#{xxpCat} f=ppid     |" # 全クラス統一pid(ppid)結合
			f << "msortf  f=class,ppid                       |"
			f << "mcommon k=class,ppid K=class,pid m=#{xxp4} |" # 列挙されたパターンの選択
			f << "mcut    f=#{@db.idFN},class,ppid:pid       |"
			f << "msortf  f=#{@db.idFN},class,pid            o=#{@tFile}"
			system(f)
		end

		@size = MCMD::mrecount("i=#{@pFile}") # 列挙されたパターンの数
		MCMD::msgLog("the number of emerging patterns enumerated is #{@size}")
	end

  def output(outpath)
		system "mv #{@pFile} #{outpath}/patterns.csv"
		system "mv #{@tFile} #{outpath}/tid_pats.csv" if @outtf
	end
end

end #module
