#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <ruby.h>
#include <sys/stat.h>


//#include "src/sspc.c"
#include "src/grhfil.c"




VALUE grhfilrun(VALUE self,VALUE argvV){
	char *p,*q,*st,**pp=NULL,**tmpp=NULL;
	unsigned int cnt =1;
	char* argstr=RSTRING_PTR(argvV);
	long len = RSTRING_LEN(argvV); 

	p = (char*)malloc( sizeof(char)*(len+1) );
	if(p == NULL){
		fprintf(stderr,"memory alloc error\n");
		return Qfalse;
	}
	strncpy(p,argstr,len);
	*(p+len)='\0';
	// スペーススキップ
	q=p ;
	while(*q==' ') { *q='\0'; q++; }
	st=q;

	pp = (char**)malloc(sizeof(char*)*(cnt));
	if(pp == NULL){
		fprintf(stderr,"memory alloc error\n");
		return Qfalse;
	}
	pp[0] = "grhfil";

	while(*q){
		if(*q==' '){
			while(*q==' ') { *q='\0'; q++; }
			tmpp = (char**)realloc(pp,sizeof(char*)*(cnt+1));
			if(tmpp==NULL){
				fprintf(stderr,"memory alloc error\n");
				free(pp);
				return Qfalse;
			}
			pp = tmpp;
			pp[cnt]= st;
			cnt++;
			st = q;
		}
		else{
			q++;
		}
	}
	if(strlen(st)!=0){
		tmpp = (char**)realloc(pp,sizeof(char*)*(cnt+1));
		if(tmpp==NULL){
			free(pp);
			return Qfalse;
		}
		pp = tmpp;
		pp[cnt]= st;
		cnt++;
	}
	GRHFIL_main(cnt,pp);
	if(pp){ free(pp);}
	if(p){ free(p);}
	return Qtrue;
}

// -----------------------------------------------------------------------------
// ruby Mcsvin クラス init
// -----------------------------------------------------------------------------
void Init_grhfilrun(void) 
{
	// モジュール定義:MCMD::xxxxの部分
	VALUE mtake=rb_define_module("TAKE");
//	rb_define_module_function(mtake,"sspc"       , (VALUE (*)(...))sspcrun,1);
	rb_define_module_function(mtake,"run_grhfil"      , grhfilrun,1);
}


