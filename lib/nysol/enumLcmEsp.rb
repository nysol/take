#!/usr/bin/env ruby
require "rubygems"
require "nysol/mcmd"
require "nysol/take"

require "nysol/seqDB.rb"

module TAKE

#========================================================================
# 列挙関数:lcm_seq 利用DB:SeqDB
#========================================================================
class LcmEsp
	attr_reader :size  # 列挙されたパターン数

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
		sigma=(beta*(omegaF-w/minGR)).to_i  # 切り捨て
		sigma=1 if sigma<=0
		return sigma
	end


	# 1:β   最小支持度
	# 2:γ   最小GR
	# 3:Dp  クラス1トランザクション数
	# 4:Dn  クラス2トランザクション数
	# 5:lcmq   LCM列挙数調整パラメータ
  # 1:γ 2:Dp 3:Dn 4:lcmq 
	#def calOmega(minGR,posCnt,negCnt,lcmq=0.5)
	#	#return (negCnt.to_f*(1-prob))/(posCnt.to_f*prob)/(1-lcmq)
	#	return negCnt.to_f/posCnt.to_f/minGR.to_f/(1-lcmq)
	#end

	#def calAlphaD(minSup,minGR,posCnt,negCnt,lcmq=0.5)
	#	return lcmq*minSup.to_f*negCnt.to_f/minGR.to_f/(1-lcmq)
	#end

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
		f << "mcut   f=#{@db.idFN},#{@db.timeFN},#{items.idFN}                         |"
		f << "msortf f=#{@db.idFN},#{@db.timeFN}%n                                     |"
		f << "mtra   k=#{@db.idFN} f=#{items.idFN}                                     |"
		f << "mcut   f=#{items.idFN} -nfno                                             o=#{@file}"
		system(f)

	end

  def enumerate(eArgs)
		tf=MCMD::Mtemp.new

		# 最小サポートと最小サポート件数
		if eArgs["minCnt"] then
			@minCnt = eArgs["minCnt"].to_i
			@minSup = @minCnt.to_f / @db.size.to_f
		else
			@minSup = eArgs["minSup"].to_f
 			@minCnt = (@minSup * @db.size.to_f + 0.99).to_i
		end

		# 最大サポートと最大サポート件数
		@maxCnt=nil
		if eArgs["maxCnt"] or eArgs["maxSup"] then
			if eArgs["maxCnt"] then
				@maxCnt = eArgs["maxCnt"].to_i
				@maxSup    = @maxCnt.to_f / @db.size.to_f
			else
				@maxSup    = eArgs["maxSup"].to_f
 				@maxCnt = (@maxSup * @db.size.to_f + 0.99).to_i
			end
		end

		#@minProb = eArgs["minProb"].to_f # 事後確率
		#@minGR   = @minProb/(1-@minProb) # 増加率
		#@minGR   = eArgs["minGR"].to_f if eArgs["minGR"]

		# あるクラスをpos、他のクラスをnegにして、パターン列挙した結果ファイル名を格納する
		pFiles=[]
		tFiles=[]
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
			if eArgs["minCnt"] then
				@minPos = eArgs["minCnt"]
			else
 				@minPos = (eArgs["minSup"] * posSize.to_f + 0.99).to_i
			end

			# 最大サポートと最大サポート件数
			if eArgs["maxCnt"] or eArgs["maxSup"] then
				if eArgs["maxCnt"] then
					@maxCnt = eArgs["maxCnt"].to_i
				else
 					@maxCnt = (eArgs["maxSup"] * posSize.to_f + 0.99).to_i
				end
			end
			@addTP = ""		
			@addTP = "m" if eArgs["exM"]
			@addTP = "c" if eArgs["exC"]


			@sigma[cName] = calSigma(@minPos,@minGR,posSize,negSize)

			# lcm_seqのパラメータ設定と実行
			lcmout = tf.file # lcm_seq出力ファイル
			# 頻出パターンがなかった場合、lcm出力ファイルが生成されないので
			# そのときのために空ファイルを生成しておいく。
			system("touch #{lcmout}")
			
			if @maxCnt then
				@maxCnt = calSigma(@maxCnt,@minGR,posSize,negSize)
			end

			run="CIA#{@addTP}"
			run << " -U #{@maxCnt}"         if @maxCnt # windowサイズ上限
			run << " -l #{eArgs['minLen']}" if eArgs["minLen"] # パターンサイズ下限
			run << " -u #{eArgs['maxLen']}" if eArgs['maxLen'] # パターンサイズ上限
			run << " -g #{eArgs['gap']}"    if eArgs['gap'] # gap上限
			run << " -G #{eArgs['win']}"    if eArgs['win'] # windowサイズ上限
			run << " -w #{@weightFile[cName]} #{@file} #{@sigma[cName]} #{lcmout}"

			# lcm_seq実行
			MCMD::msgLog("#{run}")
			if eArgs['padding'] # padding指定時は、0アイテムを出力しないlcm_seqを実行
				TAKE::run_lcmseq_zero(run)
			else
				TAKE::run_lcmseq(run)
			end
			#system run

			# パターンのサポートを計算しCSV出力する
			MCMD::msgLog("output patterns to CSV file ...")
			pFiles << @temp.file
			transle = @temp.file
			TAKE::run_lcmtrans(lcmout,"e",transle)
			f=""
			#f << "lcm_trans #{lcmout} e |" # pattern,countP,countN,size,pid
			f << "mdelnull f=pattern i=#{transle}                             |"
			f << "mcal     c='round(${countN},1)' a=neg                      |"
			f << "mcal     c='round(${countP}/#{@posWeight[cName]},1)' a=pos |"
			f << "mdelnull f=pattern                                         |"
			f << "msetstr  v=#{cName} a=class                                |"
			f << "msetstr  v=#{posSize} a=posTotal                           |"
			f << "msetstr  v=#{@minGR} a=minGR                               |"
			f << "mcut     f=class,pid,pattern,size,pos,neg,posTotal,minGR   o=#{pFiles.last}"
			system(f)

			s = MCMD::mrecount("i=#{pFiles.last}") # 列挙されたパターンの数
			MCMD::msgLog("the number of contrast patterns on class `#{cName}' enumerated is #{s}")

			if @outtf then
				# トランザクション毎に出現するシーケンスを書き出す
				MCMD::msgLog("output tid-patterns ...")
				tFiles << @temp.file

				xxw= tf.file
				f=""
				f << "mcut    f=#{@db.idFN} i=#{@db.file} |"
				f << "muniq   k=#{@db.idFN} |"
				f << "mnumber S=0 a=__tid -q|"
				f << "msortf  f=__tid       o=#{xxw}"
				system(f)
				translt = @temp.file
				TAKE::run_lcmtrans(lcmout,"t",translt)

				f=""
				#f << "lcm_trans #{lcmout} t |" #__tid,pid
				f << "msortf   f=__tid i=#{translt}          |"
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
		f << "mcut    f=class,ppid:pid,pattern,size,pos,neg,posTotal,minGR                       i=#{xxpCat} |"
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
		MCMD::msgLog("the number of emerging sequence patterns enumerated is #{@size}")
	end

  def output(outpath,rmsinfo)
  	if rmsinfo then
			system "mfldname i=#{@pFile} -q o=#{outpath}/patterns.csv"
			system "mfldname i=#{@tFile} -q o=#{outpath}/tid_pats.csv" if @outtf
		else
			system "mv #{@pFile} #{outpath}/patterns.csv"
			system "mv #{@tFile} #{outpath}/tid_pats.csv" if @outtf
		end

	end
end

end #module


