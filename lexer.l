%{
#include <stdio.h>
#include <stdlib.h>

#include "symbol.h"
#include "intermediate.h"
#include "parser.h"
#define T_eof	0

int  linecount=1;
char lastWhitespace=' ';
int  nesting;

void omitQuotes(char * string);
int	 fixEscapeChar();
int  fixHex();
int  charToInt(char );

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

{D}+				{ yylval.val=atoi(yytext); return T_int_const; }

\"([^\n\"\'\\]|{ESCAPE})*\" { char buf[strlen(yytext)]; strcpy(buf,yytext); /*omitQuotes(buf);*/ yylval.name=strdup(buf); return T_string; }

\'([^\"\'\\]|{ESCAPE})\'	{ if(yytext[1]=='\\')	yylval.val=fixEscapeChar();
							  else					yylval.val=yytext[1];	
							  return T_char_const; 
							}
 
[+|\-|*|/|#|=|<|>]	{ return yytext[0]; }
"<="				{ return T_le;	}
">="				{ return T_ge;}
"<>"				{ return T_ne;}

[\(|\)|\[|\]|,|;|:]	{ return yytext[0]; }
":="				{ return T_assign; }

%[^\n]*\n			{ /* nothing */ linecount++; }

"<*"				{ nesting=1;  BEGIN(COMMENT);}
<COMMENT>"<*"		{ nesting++; }
<COMMENT>"*>"		{ nesting--; if(nesting==0) BEGIN(INITIAL); }
<COMMENT>"\n"		{ linecount++; }
<COMMENT>"*"		{ /* nothing */ }
<COMMENT>[^*\n]		{ /* nothing */ }

{W}					{ lastWhitespace=yytext[0]; }
\n					{ linecount++; lastWhitespace='\n'; }

<<EOF>>				{ return T_eof; }

.					{ yyerror("char not recognised"); } 

%%

void omitQuotes(char * string)
{
	int i=0;
	while(string[i+1]!='"'){
		string[i]=string[i+1];
		i++;
	}
	string[i]='\0';
}

int fixEscapeChar()
{
	//indicator is the char after the backshlash
	switch(yytext[2]){
		case 'n': return '\n';
		case 't': return '\t';
		case 'r': return '\r';
		case '0': return '\0';
		case '\\': return '\\';
		case '\'': return '\'';
		case '\"': return '\'';
		case 'x': return fixHex();
		default : internal("lexer: escape char, unmatched case");
	}
}

int fixHex()
{
	int d1,d2,hex;
	d1=charToInt(yytext[3]);
	if(yytext[4]=='\'') {d2=d1; d1=0;}
	else				d2=charToInt(yytext[4]);
	hex = d1*16 + d2;
	return hex;
}

int charToInt(char c)
{
	if(c>='0' && c<='9')
		return c-'0';
	else if(c>='a' && c<='f')
		return c-'a'+10;
	else if(c>='A' && c<='F')
		return c-'A'+10;
	else
		error("lexer: %s not a proper char expression",yytext);
}
	


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




