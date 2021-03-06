#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string>
#include <ruby.h>
namespace {
#include "src/lcm_seq.c"
}

#include <kgMethod.h>

extern "C" {
	void Init_lcmseqrun(void);
}


VALUE lcmseq(VALUE self,VALUE argvV){

	string argstr=RSTRING_PTR(argvV);
	vector<char *> opts = kglib::splitToken(const_cast<char*>(argstr.c_str()), ' ',true);

	// 引数文字列へのポインタの領域はここでauto変数に確保する
	kglib::kgAutoPtr2<char*> argv;
	char** vv;
	try{
		argv.set(new char*[opts.size()+1]);
		vv = argv.get();
	}catch(...){
		rb_raise(rb_eRuntimeError,"memory allocation error");
	}

	// vv配列0番目はコマンド名
	vv[0]=const_cast<char*>("lcmseq");

	size_t vvSize;
	for(vvSize=0; vvSize<opts.size(); vvSize++){
		vv[vvSize+1] = opts.at(vvSize);
	}
	vvSize+=1;

	LCMseq_main(vvSize,vv);
	return Qtrue;
}


VALUE lcmseqk(VALUE self,VALUE argvV){

	string argstr=RSTRING_PTR(argvV);
	vector<char *> opts = kglib::splitToken(const_cast<char*>(argstr.c_str()), ' ',true);

	// 引数文字列へのポインタの領域はここでauto変数に確保する
	kglib::kgAutoPtr2<char*> argv;
	char** vv;
	try{
		argv.set(new char*[opts.size()+1]);
		vv = argv.get();
	}catch(...){
		rb_raise(rb_eRuntimeError,"memory allocation error");
	}

	// vv配列0番目はコマンド名
	vv[0]=const_cast<char*>("lcmseq");

	size_t vvSize;
	for(vvSize=0; vvSize<opts.size()-1; vvSize++){
		vv[vvSize+1] = opts.at(vvSize);
	}
	vvSize+=1;


	// 標準出力きりかえ
	int backup, fd;
	backup = dup(1);
	fd = open(opts.at(opts.size()-1), O_WRONLY|O_TRUNC|O_CREAT|O_APPEND, S_IRWXU);
	dup2(fd, 1);
 	stdout = fdopen(fd, "w");
	LCMseq_main(vvSize,vv);
	fflush (stdout);
	dup2(backup, 1); 
 	stdout = fdopen(backup, "w");
	close(backup);

	return Qtrue;
}



// -----------------------------------------------------------------------------
// ruby Mcsvin クラス init
// -----------------------------------------------------------------------------
void Init_lcmseqrun(void) 
{
	// モジュール定義:MCMD::xxxxの部分
	VALUE mtake=rb_define_module("TAKE");
	rb_define_module_function(mtake,"run_lcmseq"       , (VALUE (*)(...))lcmseq,1);
	rb_define_module_function(mtake,"run_lcmseqK"       , (VALUE (*)(...))lcmseqk,1);
}


