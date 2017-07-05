#!/usr/bin/env ruby
# encoding: utf-8
require "rubygems"
require "nysol/mcmd"

require "nysol/zdd"
require "nysol/take"
require "nysol/traDB.rb"

module TAKE

#========================================================================
# 列挙関数:lcm 利用DB:TraDB
#========================================================================
class LcmIs
	attr_reader :size  # 列挙されたパターン数
	attr_reader :pFile
	attr_reader :tFile


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

	def initialize(db)
		@temp=MCMD::Mtemp.new
		@db = db # 入力データベース
		@file=@temp.file
		items=@db.items

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

  def enumerate(eArgs)
		tf=MCMD::Mtemp.new

		@type = eArgs["type"]

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

		# lcmのパラメータ設定と実行
		#run=""
		#run << "#{CMD} #{@type}If"
		#run << " -U #{@maxCnt}"         if @maxCnt # windowサイズ上限
		#run << " -l #{eArgs['minLen']}" if eArgs["minLen"] # パターンサイズ下限
		#run << " -u #{eArgs['maxLen']}" if eArgs['maxLen'] # パターンサイズ上限

		run=""
		run << "#{@type}If"
		run << " -U #{@maxCnt}"         if @maxCnt # windowサイズ上限
		run << " -l #{eArgs['minLen']}" if eArgs["minLen"] # パターンサイズ下限
		run << " -u #{eArgs['maxLen']}" if eArgs['maxLen'] # パターンサイズ上限
		

		# 列挙パターン数上限が指定されれば、一度lcmを実行して最小サポートを得る
		@top = eArgs["top"]
    if(@top and @top>0) then
			xxtop = tf.file

			TAKE::run_lcmK("#{run} -K #{@top} #{@file} 1 #{xxtop}")			
#			system("#{run} -K #{@top} #{@file} 1 > #{xxtop}")
			File.open(xxtop,"r"){|fpr| @minCnt=fpr.gets().to_i}
			@minCnt=1 if @minCnt<0


		end

		# lcm_seq出力ファイル
		lcmout = tf.file
		# 頻出パターンがなかった場合、lcm出力ファイルが生成されないので
		# そのときのために空ファイルを生成しておいく。
		system("touch #{lcmout}")

		# lcm実行
		MCMD::msgLog("#{run} #{@file} #{@minCnt} #{lcmout}")

		TAKE::run_lcm("#{run} #{@file} #{@minCnt} #{lcmout}")
		#system("#{run} #{@file} #{@minCnt} #{lcmout}")

		# caliculate one itemset for lift value
		xxone= tf.file
		TAKE::run_lcm("FIf -l 1 -u 1 #{@file} 1 #{xxone}")
		#system("#{CMD} FIf -l 1 -u 1 #{@file} 1 #{xxone}")

		# パターンのサポートを計算しCSV出力する
		MCMD::msgLog("output patterns to CSV file ...")
		xxp0=tf.file
		@pFile = @temp.file
		items=@db.items
		trans0 = @temp.file
		TAKE::run_lcmtrans(lcmout,"p",trans0)

		f=""
#		f << "lcm_trans #{lcmout} p |" # pattern,count,size,pid
		f << "mdelnull f=pattern i=#{trans0}                                         |"
		f << "mvreplace vf=pattern m=#{items.file} K=#{items.idFN} f=#{items.itemFN} |"
		f << "msetstr  v=#{@db.size} a=total                                         |" # トータル件数
		f << "mcal     c='${count}/${total}' a=support                               |" # サポートの計算
		f << "mcut     f=pid,pattern,size,count,total,support                        |"
		f << "mvsort   vf=pattern |"
		f << "msortf   f=pid                                                         o=#{xxp0}"
		system(f)
		# xxp0
		# pid,count,total,support,pattern
		# 0,13,13,1,A
		# 4,6,13,0.4615384615,A B

		xxp1=tf.file
		# taxonomy指定がない場合(2010/11/20追加)
		if items.taxonomy==nil then
			FileUtils.mv(xxp0, xxp1)

		# taxonomy指定がある場合
		else
			MCMD::msgLog("reducing redundant rules in terms of taxonomy ...")
			zdd=ZDD.constant(0)
			MCMD::Mcsvin.new("i=#{xxp0}"){|csv|
				csv.each{|fldVal|
					pat=fldVal['pattern']
					zdd=zdd+ZDD.itemset(pat)
				}
			}

			zdd=reduceTaxo(zdd,@db.items)
			xxz1=tf.file
			xxz2=tf.file
			zdd.csvout(xxz1)
			f=""
			f << "mcut   -nfni f=1:pattern i=#{xxz1} |"
			f << "mvsort vf=pattern        |"
			f << "msortf f=pattern         o=#{xxz2}"
			system(f)

			f=""
			f << "msortf  f=pattern           i=#{xxp0} |"
			f << "mcommon k=pattern m=#{xxz2} |"
			f << "msortf  f=pid               o=#{xxp1}"
			system(f)
		end

		# lift値の計算
		xxp2=tf.file

		transl = tf.file
		
		TAKE::run_lcmtrans(xxone,"p",transl)

		f=""
#		f << "lcm_trans #{xxone} p |" # pattern,count,size,pid
		f << "mdelnull f=pattern  i=#{transl}                                        |"
		f << "mvreplace vf=pattern m=#{items.file} K=#{items.idFN} f=#{items.itemFN} |"
		f << "msortf f=pattern o=#{xxp2}"
		system(f)

		xxp3=tf.file
		f=""
		f << "mcut   f=pid,pattern  i=#{xxp1} |"
		f << "mtra   f=pattern -r |"
		f << "msortf f=pattern |"
		f << "mjoin  k=pattern m=#{xxp2} f=count:c1 |"
		f << "mcal   c='ln(${c1})' a=c1ln |"
		f << "msortf f=pid |"
		f << "msum   k=pid f=c1ln o=#{xxp3}"
		system(f)

		# p3
		# pid,pattern,c1,c1ln
		# 0,A,13,2.564949357
		# 1,E,7,1.945910149
		f=""
		f << "mjoin k=pid m=#{xxp3} f=c1ln i=#{xxp1} |"
		f << "mcal c='round(exp(ln(${count})-${c1ln}+(${size}-1)*ln(${total})),0.0001)' a=lift |"
		f << "mcut f=pid,size,count,total,support,lift,pattern |"
		f << "msortf f=support%nr o=#{@pFile}"
		system(f)

		@size = MCMD::mrecount("i=#{@pFile}") # 列挙されたパターンの数
		MCMD::msgLog("the number of patterns enumerated is #{@size}")

		# トランザクション毎に出現するシーケンスを書き出す
		MCMD::msgLog("output tid-patterns ...")
		@tFile = @temp.file

		xxw1= tf.file
		f=""
		f << "mcut    f=#{@db.idFN} i=#{@db.file} |"
		f << "muniq   k=#{@db.idFN}  |"
		f << "mnumber S=0 a=__tid -q |"
		f << "msortf  f=__tid       o=#{xxw1}"
		system(f)

		xxw2= tf.file
		f=""
		f << "mcut    f=pid i=#{@pFile} |"
		f << "msortf  f=pid o=#{xxw2}"
		system(f)

		xxw3 = tf.file
		TAKE::run_lcmtrans(lcmout,"t",xxw3)
		f=""
#		f << "lcm_trans #{lcmout} t |" #__tid,pid
		f << "msortf   f=pid  i=#{xxw3}                 |"
		f << "mcommon  k=pid m=#{xxw2}                 |"
		f << "msortf   f=__tid                         |"
		f << "mjoin    k=__tid m=#{xxw1} f=#{@db.idFN} |"
		f << "mcut     f=#{@db.idFN},pid               o=#{@tFile}"
		system(f)
	end

  def output(outpath)
		system "mv #{@pFile} #{outpath}/patterns.csv"
		system "mv #{@tFile} #{outpath}/tid_pats.csv"
	end
end

end #module

