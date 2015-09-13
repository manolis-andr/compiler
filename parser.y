%{
#include <stdio.h>
#include <stdlib.h>

%}

%token T_and	"and"
%token T_bool	"bool"
%token T_char	"char"
%token T_decl	"decl"
%token T_def	"def"
%token T_else	"else"
%token T_elsif	"elsif"
%token T_end	"end"
%token T_exit	"exit"
%token T_false	"false"
%token T_for	"for"
%token T_head	"head"
%token T_if		"if"
%token T_int	"int"
%token T_list	"list"
%token T_mod	"mod"
%token T_new	"new"
%token T_nil	"nil"
%token T_nilq	"nilq"
%token T_not	"not"
%token T_or		"or"
%token T_ref	"ref"
%token T_return	"return"
%token T_skip	"skip"
%token T_tail	"tail"
%token T_true	"true"
%token T_le		"<="
%token T_ge		">="
%token T_ne		"<>"
%token T_assign	":="

%token T_id		
%token T_int_const	
%token T_char_const
%token T_string

%left "or"
%left "and"
%nonassoc "not"		/* This is a unary operator, associativity has no meaning */
%nonassoc '=' "<>" '<' '>' "<=" ">=" 
%right '#'
%left '+' '-'
%left '*' '/' "mod"

%%

program		: func_def ;
func_def	: "def" header ':' def_list stmt_list "end" ;

def_list	: func_def def_list 
			| func_decl def_list 
			| var_def def_list 
			| /* nothing */
			;

header		: type T_id '(' formal_list ')' 
			| T_id '(' formal_list ')' 
			;

formal_list	: formal formal_full | ;
formal_full	: ';' formal formal_full | /* nothing */;

formal		: "ref" type id_list 
			| type id_list
			;

id_list		: T_id id_full ;
id_full		: ',' T_id id_full | /* nothing */;

type		: "int" 
			| "bool" 
			| "char" 
			| type '[' ']' 
			| "list" '[' type ']' 
			
func_decl	: "decl" header ;

var_def		: type id_list ;

stmt_list	: stmt stmt_full ;
stmt_full	: stmt stmt_full | /* nothing */;

stmt		: simple 
			| "exit" 
			| "return" expr 
			| if_clause 
			| "for" simple_list ';' expr ';' simple_list ':' stmt_list "end" ; 

if_clause	: "if" expr ':' stmt_list elsif_clause else_clause "end" ;
elsif_clause: "elsif" expr ':' stmt_list elsif_clause | /* nothing */;
else_clause	: "else" ':' stmt_list | /* nothing */;

simple		: "skip" 
			| atom ":=" expr 
			| call 
			;

simple_list	: simple simple_full ; 
simple_full	: ',' simple simple_full | /* nothing */;

call		: T_id '(' expr_list ')' 
			| T_id '(' ')' 
			;

expr_list	: expr expr_full ;
expr_full	:',' expr expr_full | /* nothing */;

atom		: T_id 
			| T_string
			| atom '[' expr ']' 
			| call 
			;


expr		: atom
			| T_int_const
			| T_char_const
			| '(' expr ')' 
			| '+' expr
			| '-' expr
			| expr '+' expr
			| expr '-' expr
			| expr '*' expr
			| expr '/' expr
			| expr "mod" expr
			| expr '=' expr
			| expr "<>" expr
			| expr '<' expr
			| expr '>' expr
			| expr "<=" expr
			| expr ">=" expr
			| "true" 
			| "false" 
			| "not" expr
			| expr "and" expr
			| expr "or" expr
			| "new" type '[' expr ']'
			| "nil" 
			| "nilq" '(' expr ')'
			| expr '#' expr 
			| "head" '(' expr ')' 
			| "tail" '(' expr ')'
			;

%%

int yyerror(const char *msg){
	fprintf(stderr,"syntax error: %s\n",msg);
	exit(1);
}

int main(){

	return yyparse();

}
