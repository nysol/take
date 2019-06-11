#!/usr/bin/env ruby
# encoding: utf-8
require "rubygems"
require "nysol/mcmd"
require "nysol/take"
require "nysol/seqDB.rb"

module TAKE

#========================================================================
# 列挙関数:lcmseq 利用DB:SeqDB
#========================================================================
class LcmSeq
	attr_reader :size  # 列挙されたパターン数

	def initialize(db,outtf=true)
		@temp=MCMD::Mtemp.new
		@db = db # 入力データベース
		@file=@temp.file
		items=@db.items
		@outtf = outtf

		# アイテムをシンボルから番号に変換する。
		f=""
		f << "msortf f=#{@db.itemFN}                                                   i=#{@db.file} |"
		f << "mjoin  k=#{@db.itemFN} K=#{items.itemFN} m=#{items.file} f=#{items.idFN} |"
		f << "mcut   f=#{@db.idFN},#{@db.timeFN},#{items.idFN}                         |"
		f << "msortf f=#{@db.idFN},#{@db.timeFN}%n                                     |"
		f << "mtra   k=#{@db.idFN} s=#{@db.timeFN}%n f=#{items.idFN}                                     |"
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

		# 列挙パターン数上限が指定されれば、一度lcmを実行して最小サポートを得る
		@top = eArgs["top"]
    if(@top and @top>0) then
			xxtop = tf.file
			TAKE::run_lcmseqK("Cf -K #{@top} #{@file} 1 #{xxtop}")
			#system("#{CMD} Cf -K #{@top} #{@file} 1 > #{xxtop}")
			File.open(xxtop,"r"){|fpr| @minCnt=fpr.gets().to_i}
			@minCnt=1 if @minCnt<0
		end
		
		@addTP = ""		
		@addTP = "m" if eArgs["exM"]
		@addTP = "c" if eArgs["exC"]
			


		# lcm_seq出力ファイル
		lcmout = tf.file
		# 頻出パターンがなかった場合、lcm出力ファイルが生成されないので
		# そのときのために空ファイルを生成しておいく。
		system("touch #{lcmout}")

		# lcm_seqのパラメータ設定と実行
		run="CIf#{@addTP}"
		run << " -U #{@maxCnt}"         if @maxCnt # windowサイズ上限
		run << " -l #{eArgs['minLen']}" if eArgs["minLen"] # パターンサイズ下限
		run << " -u #{eArgs['maxLen']}" if eArgs['maxLen'] # パターンサイズ上限
		run << " -g #{eArgs['gap']}"    if eArgs['gap'] # gap上限
		run << " -G #{eArgs['win']}"    if eArgs['win'] # windowサイズ上限
		run << " #{@file} #{@minCnt} #{lcmout}"

		# lcm_seq実行
		MCMD::msgLog("#{run}")

		if eArgs['padding'] # padding指定時は、0アイテムを出力しないlcm_seqを実行
			TAKE::run_lcmseq_zero(run)
		else
			TAKE::run_lcmseq(run)
		end
		#system run

		# パターンのサポートを計算しCSV出力する
		@pFile = @temp.file
		items=@db.items

		transl = @temp.file
		TAKE::run_lcmtrans(lcmout,"p",transl)

		f=""
		#f << "lcm_trans #{lcmout} p |" # pattern,count,size,pid
		f << "mdelnull f=pattern  i=#{transl}                                         |"
		f << "mvreplace vf=pattern m=#{items.file} K=#{items.idFN} f=#{items.itemFN}  |"
		f << "msetstr  v=#{@db.size} a=total                                          |" # トータル件数
		f << "mcal     c=\'${count}/${total}\' a=support                              |" # サポートの計算
		f << "mcut     f=pid,pattern,size,count,total,support                         |"
		f << "msortf   f=support%nr                                                   o=#{@pFile}"
		system(f)

		if @outtf then
			# トランザクション毎に出現するシーケンスを書き出す
			MCMD::msgLog("output tid-patterns ...")
			@tFile = @temp.file

			xxw = tf.file #Mtemp.new.name
			f=""
			f << "mcut    f=#{@db.idFN} i=#{@db.file} |"
			f << "muniq   k=#{@db.idFN}  |"
			f << "mnumber S=0 a=__tid -q |"
			f << "msortf  f=__tid       o=#{xxw}"
			system(f)

			translt = @temp.file
			TAKE::run_lcmtrans(lcmout,"t",translt)

			f=""
			#		f << "lcm_trans #{lcmout} t |" #__tid,pid
			f << "msortf   f=__tid i=#{translt}           |"
			f << "mjoin    k=__tid m=#{xxw} f=#{@db.idFN} |"
			f << "mcut     f=#{@db.idFN},pid              |"
			f << "msortf   f=#{@db.idFN},pid              o=#{@tFile}"
			system(f)
		end

		@size = MCMD::mrecount("i=#{@pFile}") # 列挙されたパターンの数
		MCMD::msgLog("the number of contrast patterns enumerated is #{@size}")
	end

  def output(outpath)
		system "mv #{@pFile} #{outpath}/patterns.csv"
		system "mv #{@tFile} #{outpath}/tid_pats.csv" if @outtf
	end
end

end #module
