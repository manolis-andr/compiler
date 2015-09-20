%{
#include <stdio.h>
#include <stdlib.h>

#include "symbol.h"
#include "parser.h"
#define T_eof	0

int linecount=1;
char lastWhitespace=' ';
int nesting;

%}

L [A-Za-z]		
D [0-9]			
W [ \t\r]		
HEX [0-9|A-F|a-f] 	
ESCAPE \\(n|t|r|0|\\|\'|\"|x{HEX}{HEX})

%x COMMENT

%%

"and"		{ return T_and; }
"end"		{ return T_end; }
"list"		{ return T_list; }
"ref"		{ return T_ref; }
"bool"		{ return T_bool; }
"exit"		{ return T_exit; }
"mod"		{ return T_mod; }
"return"	{ return T_return; }
"char"		{ return T_char; }
"false"		{ return T_false; }
"new"		{ return T_new; }
"skip"		{ return T_skip; }
"decl"		{ return T_decl; }
"for"		{ return T_for; }
"nil"		{ return T_nil; }
"tail"		{ return T_tail; }
"def"		{ return T_def; }
"head"		{ return T_head; }
"nil?"		{ return T_nilq; }
"true"		{ return T_true; }
"else"		{ return T_else; }
"or"		{ return T_or; }
"int"		{ return T_int; }
"if"		{ return T_if; }
"not"		{ return T_not; }
"elsif"		{ return T_elsif; }


{L}({L}|{D}|_|\?)*	{ yylval.name=strdup(yytext); return T_id;}

{D}+		{ return T_int_const; }

\"([^\n\"\'\\]|{ESCAPE})*\" { return T_string; }

\'([^\"\'\\]|{ESCAPE})\' { return T_char_const; }

 
[+|\-|*|/|#|=|<|>]	{ return yytext[0]; }
"<="			{ return T_le;}
">="			{ return T_ge;}
"<>"			{ return T_ne;}

[\(|\)|\[|\]|,|;|:]	{ return yytext[0]; }
":="			{ return T_assign; }

%[^\n]*\n		{ /* nothing */ linecount++; }

"<*"			{ nesting=1;  BEGIN(COMMENT);}
<COMMENT>"<*"	{ nesting++; }
<COMMENT>"*>"	{ nesting--; if(nesting==0) BEGIN(INITIAL); }
<COMMENT>"\n"	{ linecount++; }
<COMMENT>"*"	{ /* nothing */ }
<COMMENT>[^*\n]	{ /* nothing */ }

{W}				{ lastWhitespace=yytext[0]; }
\n				{ linecount++; lastWhitespace='\n'; }

<<EOF>>			{ return T_eof; }

.				{ yyerror("char not recognised"); } 

%%

/*void ERROR(const char msg[]){
	fprintf(stderr,"ERROR: %s\n",msg);
	exit(1);
}*/


/* Not needed any more
int main(){
	int token;
	
	do{
		token = yylex(); 
		printf("token=%d, lexeme=\"%s\"\n",token,yytext);
	} while (token!=T_eof);

	return 0;
}*/




