%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "symbol.h"
#include "error.h"
#include "general.h"


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

header		: type T_id '(' formal_list ')'	{} /* check that T_id is uniquely defined in the current scope (not already in Symbol Table) */
			| T_id '(' formal_list ')'		/* check that T_id is uniquely defined in the current scope (not already in Symbol Table) */
			;

formal_list	: formal formal_full | /* nothing */;
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
			;

func_decl	: "decl" header /* check if function has already a forward redeclaration in the current scope */ ;

var_def		: type id_list /* check if a variable has been redeclared in the current scope as some other entry */  ;


stmt_list	: stmt stmt_full ;
stmt_full	: stmt stmt_full | /* nothing */;

stmt		: simple 
			| "exit"			/* check that this exit stmt is in a block (function) with a return type TYPE_VOID */
			| "return" expr		/* check that this return stmt is in a block (function) with a return type t same as the expr.type */ 
			| if_clause 
			| "for" simple_list ';' expr ';' simple_list ':' stmt_list "end" /* check that expr has type bool */
			


			/* check that expr has type bool, if an expression is evaluated true then we do not evaluate the other elif/else branches */ 
			/* the following of grammar allows the desired behaviour from is-clauses */
if_clause	: "if" expr ':' stmt_list elsif_clause else_clause "end" ;
elsif_clause: "elsif" expr ':' stmt_list elsif_clause | /* nothing */;
else_clause	: "else" ':' stmt_list | /* nothing */;

simple		: "skip" 
			| atom ":=" expr /* atom is l-value && expr.type=atom.typ */
			| call 
			;

simple_list	: simple simple_full ; 
simple_full	: ',' simple simple_full | /* nothing */;

call		: T_id '(' expr_list ')'	/* check that T_id is ENTRY_FUNCTION && check function call limitations */
			| T_id '(' ')'				/* check that T_id is ENTRY_FUNCTION && check function call limitations */
			;

expr_list	: expr expr_full ;
expr_full	:',' expr expr_full | /* nothing */;

atom		: T_id 
			| T_string
			| array_cell	/* we modified our grammar right here */ 
			| call 
			;

array_cell	: T_id '[' expr ']'
			| array_cell '[' expr ']'
			

/* check TYPES for all of the expression forms below */
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
			

/* function call limitations 
 * 1. T_id name of the function exists in current scope
 * 2. num of arguments in call is equal with num definition
 * 3. types of arguments passed are of the same type
 * 4. if arguments are passed by reference, they must be valid l-values
 * /

/* In each T_id allocation we must check if the specific T_id is uniqe = 1st time to be created. ONLY in T_id ALLOCAATION */


%%

extern FILE * yyin;

const char * filename;
int FFLAG = 0;
int IFLAG = 0;
int OFLAG = 0;


int yyerror(const char *msg){
	fprintf(stderr,"syntax error: %s\n",msg);
	exit(1);
}


void parseArguments(int argc,char * argv[]){

	int i, fileArg=0;
	for(i=1;i<argc;i++){
		if(strcmp(argv[i],"-f")==0)
			FFLAG=1;
		else if(strcmp(argv[i],"-i")==0)
			IFLAG=1;
		else if(strcmp(argv[i],"-O")==0)
			OFLAG=1;
		else if(fileArg==0)
			fileArg=i;
		else
			fatal("uknown flag or excessive input argument");
	}
	if(fileArg && (FFLAG || IFLAG))
		fatal("too many input arguments. Omit flags or source fielname");
	else if (!FFLAG && !IFLAG && !fileArg)
		fatal("too few input arguments. Specify source filename");

	/* Input Filename Specification */
#define FILENAME_SIZE 30
	char *file = (char *) new(FILENAME_SIZE*sizeof(char));

	if(FFLAG || IFLAG)
		snprintf(file,FILENAME_SIZE,"stdin");
	else
		memcpy(file,argv[fileArg],FILENAME_SIZE);
	filename = file;

#if DEBUG
	printf("compiling file: %s\n",filename);
#endif

}


int main(int argc, char * argv[]){


	/* Arguments parsing */
	parseArguments(argc,argv);

	/* Open file and redirect yylex to it */
	if(!FFLAG && !IFLAG){
		yyin = fopen(filename,"r");
		if(yyin==NULL) fatal("filename %s is not valid. The file cannot be found.",filename);
	}

	/* Initializing Symbol Table  */
#ifndef SYMBOLTABLE_SIZE
	#define SYMBOLTABLE_SIZE 2003
#endif
	initSymbolTable(SYMBOLTABLE_SIZE);

	/* Calling the syntax parser */
	return yyparse();

}
