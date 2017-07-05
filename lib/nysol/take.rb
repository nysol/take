#!/usr/bin/env ruby
#/* ////////// LICENSE INFO ////////////////////
#
# * Copyright (C) 2013 by NYSOL CORPORATION
# *
# * Unless you have received this program directly from NYSOL pursuant
# * to the terms of a commercial license agreement with NYSOL, then
# * this program is licensed to you under the terms of the GNU Affero General
# * Public License (AGPL) as published by the Free Software Foundation,
# * either version 3 of the License, or (at your option) any later version.
# * 
# * This program is distributed in the hope that it will be useful, but
# * WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF 
# * NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# *
# * Please refer to the AGPL (http://www.gnu.org/licenses/agpl-3.0.txt)
# * for more details.
#
# ////////// LICENSE INFO ////////////////////*/

#= MCMD ruby拡張ライブラリ
#Mコマンドruby拡張ライブラリとは、MCMDで提供されている各種データ処理モジュールをrubyから利用できるようにするインターフェースを提供する。
#
#mcmd.rbは、以下の6つのクラスライブラリをrequireしている。
# require "mcsvin"   # MCMD::CSVin   CSVの行単位読み込みクラス (c++で作成された共有ライブラリ)
# require "mcsvout"  # MCMD::CSVout  CSVの出力クラス (c++で作成された共有ライブラリ)
# require "mtable"   # MCMD::Table   CSVのメモリ展開クラス (c++で作成された共有ライブラリ)
# require "margs"    # MCMD::Args    コマンドライン引数を扱うクラス(rubyスクリプト)
# require "mtemp"    # MCMD::Temp    一時ファイル管理(rubyスクリプト)

require "nysol/lcmrun"
require "nysol/lcmseqrun"
require "nysol/lcmseq0run"
require "nysol/lcmtransrun"
require "nysol/sspcrun"
require "nysol/grhfilrun"
require "nysol/macerun"


