#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ruby.h>
#include <kgMethod.h>

#define MAXC 1024000

extern "C" {
	void Init_lcmtransrun(void);
}

int lcmtrans(int argc, char **argv){
	char mode;
	char *hd;
	if(argc==2 && 0==strcmp(*(argv+1),"-v" )){
		fprintf(stderr,"lcm_trans 1.0\n");
		return 1;
	}

	if(argc!=4){
hd="\
usage) lcm_trans filename p|t\n\
filename: output file by lcm(lcm_seq)\n\
p: output patterns and their frequency\n\
t: output transaction number with pattern ID\n\
\n\
ex. of input file(output file by lcm)\n\
-----------\n\
 3\n\
 0 1 2\n\
4 2\n\
 0 2\n\
4 8 1\n\
 0\n\
4 8 6 1\n\
 0\n\
-----------\n\
odd line: pattern with frequency\n\
even line: transaction number \n\
\n\
standard output (2nd parameter is 'p')\n\
pattern,count,size,pid\n\
,3,0,0\n\
4,2,1,1\n\
4 8,1,2,2\n\
4 8 6,1,3,3\n\
\n\
standard output (2nd parameter is 't')\n\
__tid,pid\n\
0,0\n\
1,0\n\
2,0\n\
0,1\n\
2,1\n\
0,2\n\
0,3\n\
";
		fprintf(stderr,"%s",hd);
		return EXIT_FAILURE;
	}

	if(**(argv+2)=='p'){
		mode='p';
	}else if(**(argv+2)=='e'){
		mode='e';
	}else if(**(argv+2)=='t'){
		mode='t';
	}else{
		fprintf(stderr,"argument error2: %s\n",argv+2);
	}

	FILE *fp;
	if((fp=fopen(*(argv+1),"rb"))==NULL){
		fprintf(stderr,"file open error\n");
		return EXIT_FAILURE;
	}
	FILE *ofp;
	if((ofp=fopen(*(argv+3),"w"))==NULL){
		fprintf(stderr,"file open error\n");
		return EXIT_FAILURE;
	}



	int odd=1; // 奇数行フラグ

	// enumLcmSeq.rb,enumLcmIs.rbでのパターン
	// 4 5 (2)
	if(mode=='p'){
		fprintf(ofp,"pattern,count,size,pid\n");
		size_t recNo=0;
		char buf[MAXC]; // 出力バッファ
		char buf2[MAXC]; // 出力バッファ
		int spcCount=0; // スペースのカウント
		int opos=-1;

		while(1){
			int rsize = fread(buf, sizeof(char), MAXC, fp);
			if( rsize < 0 ){ 
				fprintf(stderr,"file read error\n");
				return EXIT_FAILURE;
			}
			if( rsize == 0 ) { break;}
			int i;
			for(i=0 ; i<rsize ;i++){
				if(buf[i]=='\n'){
					if(odd==1){
						fprintf(ofp,"%s,%d,%ld\n",buf2,spcCount,recNo);
						recNo++;
					}
					spcCount=0;
					opos=-1;
					odd*=(-1);
					continue;
				}
				if(odd!=1) { continue;}
				if(buf[i]==' '){
					buf2[++opos]=buf[i];
					if(opos!=0){ spcCount++; }
				}
				else if(buf[i]=='('){
					buf2[opos]=',';
				}
				else if(buf[i]==')'){
					buf2[++opos]='\0';
				}
				else { buf2[++opos]=buf[i];}
			}
		}
	}else if(mode=='e'){
		fprintf(ofp,"pattern,countP,countN,size,pid\n");
		size_t recNo=0;
		char buf[MAXC]; // 出力バッファ
		char buf2[MAXC]; // 出力バッファ
		int spcCount=0; // スペースのカウント
		int comCount=0; // スペースのカウント
		int opos=-1;

		while(1){
			int rsize = fread(buf, sizeof(char), MAXC, fp);
			if( rsize < 0 ){ 
				fprintf(stderr,"file read error\n");
				return EXIT_FAILURE;
			}
			if( rsize == 0 ) { break;}
			int i;
			for(i=0 ; i<rsize ;i++){
				if(buf[i]=='\n'){
					if(odd==1){
						fprintf(ofp,"%s,%d,%ld\n",buf2,spcCount,recNo);
						recNo++;
					}
					spcCount=0;
					comCount=0;
					opos=-1;
					odd*=(-1);
					continue;
				}
				if(odd!=1) { continue;}
				if(buf[i]==' '){
					buf2[++opos]=buf[i];
					if(opos!=0){ spcCount++; }
				}
				else if(buf[i]=='('){
					buf2[opos]=',';
				}
				else if(buf[i]==','){
					comCount++;
					if(comCount==2){ buf2[++opos]='\0';}
					else{ buf2[++opos]=buf[i];}
				}
				else { buf2[++opos]=buf[i];}
			}
		}

	}else{
		fprintf(ofp,"__tid,pid\n");
		size_t recNo=0;
		int opos=-1;
		char buf[MAXC]; // 出力バッファ
		char buf2[MAXC]; // 出力バッファ

		while(1){
			int rsize = fread(buf, sizeof(char), MAXC, fp);
			if( rsize < 0 ){ 
				fprintf(stderr,"file read error\n");
				return EXIT_FAILURE;
			}
			if( rsize == 0 ) { break;}
			int i;
			for(i=0 ; i<rsize ;i++){
				if(odd==1){//奇数行は¥nまでなにもしない
					if(buf[i]=='\n'){
						opos=-1;
						odd*=(-1);
						buf2[0]='\0';
					}
				}
				else{
					if(buf[i]==' '||buf[i]=='\n'){
						buf2[++opos]='\0';
						if(buf2[0] != '\0'){
							fprintf(ofp,"%s,%ld\n",buf2,recNo);
						}
						opos=-1;
						if(buf[i]=='\n'){ 
							odd*=(-1);
							recNo++;
						}
					}
					else{ buf2[++opos]=buf[i]; }
				}
			}
		}
	}

	if(0!=fclose(fp)){
		fprintf(stderr,"file close error\n");
		return EXIT_FAILURE;
	}
	if(0!=fclose(ofp)){
		fprintf(stderr,"file close error\n");
		return EXIT_FAILURE;
	}
	return 0;
}

VALUE lcm_trans(int argc, VALUE *argvV, VALUE self){
	VALUE inf;
	VALUE para;
	VALUE outf;
	rb_scan_args(argc, argvV, "30",&inf,&para,&outf);

	// 引数文字列へのポインタの領域はここでauto変数に確保する
	size_t vvSize=4;
	
	kglib::kgAutoPtr2<char*> argv;
	char** vv;
	try{
		argv.set(new char*[vvSize]);
		vv = argv.get();
	}catch(...){
		rb_raise(rb_eRuntimeError,"memory allocation error");
	}
	// vv配列0番目はコマンド名
	vv[0]=const_cast<char*>("lcm_trans");
	vv[1]=RSTRING_PTR(inf);
	vv[2]=RSTRING_PTR(para);
	vv[3]=RSTRING_PTR(outf);
	lcmtrans(vvSize,vv);
	return Qtrue;

}



void Init_lcmtransrun(void) 
{
	// モジュール定義:MCMD::xxxxの部分
	VALUE mtake=rb_define_module("TAKE");
	rb_define_module_function(mtake,"run_lcmtrans" , (VALUE (*)(...))lcm_trans,-1);

}
