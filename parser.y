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

/* Struct for remembering previous symbol table options, when we dig deeper into the symbols */
struct Memory{
	SymbolEntry *	func;
	Type			type;
	PassMode		ref;
	int				forward;
} mem;

%}

%union{
	Type type;
	char * name;
}

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
%token T_nilq	"nil?"
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

%token<name> T_id
%token T_int_const	
%token T_char_const
%token T_string

%type<type> expr
%type<type> atom
%type<type> type
%type<type> call
%type<type> array_cell

%left "or"
%left "and"
%nonassoc "not"		/* This is a unary operator, associativity has no meaning */
%nonassoc '=' "<>" '<' '>' "<=" ">=" 
%right '#'
%left '+' '-'
%left '*' '/' "mod"

%%

program		: {openScope();} func_def {closeScope();};
func_def	: "def" {mem.forward=0;} header ':' def_list stmt_list "end" {closeScope();} ;

def_list	: func_def def_list 
			| func_decl def_list	
			| var_def def_list		
			| /* nothing */
			;

header		: type T_id		{	mem.func = newFunction($2); 
								if(mem.forward==1) 
									forwardFunction(mem.func); 
								openScope();
							} 
				'(' formal_list ')' {endFunctionHeader(mem.func,$1);}	 
			/* check that T_id is uniquely defined in the current scope (not already in Symbol Table) */
			| T_id			{	mem.func = newFunction($1); 
								if(mem.forward==1) 
									forwardFunction(mem.func); 
								openScope();
							} 
				'(' formal_list ')' {endFunctionHeader(mem.func,typeVoid);}	
			/* check that T_id is uniquely defined in the current scope (not already in Symbol Table) */
			;

formal_list	: formal formal_full | /* nothing */;
formal_full	: ';' formal formal_full | /* nothing */;

formal		: "ref" type {mem.ref=PASS_BY_REFERENCE; mem.type=$2;} id_par_list
			| type {mem.ref=PASS_BY_VALUE; mem.type=$1;} id_par_list
			;

id_par_list : T_id {newParameter($1,mem.type,mem.ref,mem.func);} id_par_full ;
id_par_full : ',' T_id {newParameter($2,mem.type,mem.ref,mem.func);} id_par_full | /* nothing */ ;


type		: "int"					{$$=typeInteger;}
			| "bool"				{$$=typeBoolean;}
			| "char"				{$$=typeChar;}
			| type '[' ']'			{$$=typeIArray($1);}
			| "list" '[' type ']'	{$$=typeList($3);}
			;

func_decl	: "decl" {mem.forward=1;} header /* check if function has already a forward redeclaration in the current scope */ ;

var_def		: type {mem.type=$1;} id_list /* check if a variable has been redeclared in the current scope as some other entry */  ;

id_list		: T_id {newVariable($1,mem.type);} id_full ;
id_full		: ',' T_id {newVariable($2,mem.type);} id_full | /* nothing */;


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

call		: T_id '(' expr_list ')'	{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); $$=s->u.eFunction.resultType;}	
			/* check that T_id is ENTRY_FUNCTION && check function call limitations */
			| T_id '(' ')'				{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); $$=s->u.eFunction.resultType;}	
			/* check that T_id is ENTRY_FUNCTION && check function call limitations */
			;

expr_list	: expr expr_full ;
expr_full	:',' expr expr_full | /* nothing */;

atom		: T_id			{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); $$=s->u.eVariable.type;}
			| T_string		{$$=typeIArray(typeChar);} /*FIXME: Array of char NOT IArray, set lexer to return size*/
			| array_cell	/* we modified our grammar right here */ {$$=$1;}
			| call			{$$=$1;}
			;

array_cell	: T_id '[' expr ']' {SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); $$=s->u.eVariable.type;}
			| array_cell '[' expr ']'	/* Check that not excessive brackets have been placed */
			

/* check TYPES for all of the expression forms below */
expr		: atom				{$$=$1;}
			| T_int_const		{$$=typeInteger;}
			| T_char_const		{$$=typeChar;}		
			| '(' expr ')'		{$$=$2;} 
			| '+' expr			{if(equalType($2,typeInteger)) $$=typeInteger; else yyerror("operator takes int");}
			| '-' expr			{if(equalType($2,typeInteger)) $$=typeInteger; else yyerror("operator takes int");}
			| expr '+' expr		{if(equalType($1,typeInteger) && equalType($3,typeInteger)) $$=typeInteger; else yyerror("operator takes int operands");}	
			| expr '-' expr		{if(equalType($1,typeInteger) && equalType($3,typeInteger)) $$=typeInteger; else yyerror("operator takes int operands");}		
			| expr '*' expr		{if(equalType($1,typeInteger) && equalType($3,typeInteger)) $$=typeInteger; else yyerror("operator takes int operands");}	
			| expr '/' expr		{if(equalType($1,typeInteger) && equalType($3,typeInteger)) $$=typeInteger; else yyerror("operator takes int operands");}	
			| expr "mod" expr	{if(equalType($1,typeInteger) && equalType($3,typeInteger)) $$=typeInteger; else yyerror("operator takes int operands");}	
			| expr '=' expr		{if(equalType($1,$3)) $$=typeBoolean; else yyerror("type mismatch between operands");}
			| expr "<>" expr	{if(equalType($1,$3)) $$=typeBoolean; else yyerror("type mismatch between operands");}
			| expr '<' expr		{if(equalType($1,$3)) $$=typeBoolean; else yyerror("type mismatch between operands");}
			| expr '>' expr		{if(equalType($1,$3)) $$=typeBoolean; else yyerror("type mismatch between operands");}
			| expr "<=" expr	{if(equalType($1,$3)) $$=typeBoolean; else yyerror("type mismatch between operands");}
			| expr ">=" expr	{if(equalType($1,$3)) $$=typeBoolean; else yyerror("type mismatch between operands");}
			| "true"			{$$=typeBoolean;}
			| "false"			{$$=typeBoolean;}
			| "not" expr		{$$=typeBoolean;}
			| expr "and" expr	{if(equalType($1,typeBoolean) && equalType($3,typeBoolean)) $$=typeBoolean; else yyerror("operator takes bbolean operands");}
			| expr "or" expr	{if(equalType($1,typeBoolean) && equalType($3,typeBoolean)) $$=typeBoolean; else yyerror("operator takes bbolean operands");}
			| "new" type '[' expr ']'	{if(equalType($4,typeInteger)) $$=typeIArray($2); else yyerror("array size must be integer whereas expression in brackets is not");}
			| expr '#' expr				{if(equalType($3,typeList(typeAny)) && equalType($1,$3->refType)) $$=$3; else yyerror("type mismatch in list construction");}
			| "nil"						{$$=typeList(typeAny);}
			| "nil?" '(' expr ')'		{if(equalType($3,typeList(typeAny))) $$=typeBoolean; else yyerror("expression in brackets must be some list type");}
			| "head" '(' expr ')'		{if(equalType($3,typeList(typeAny))) $$=$3->refType; else yyerror("expression in brackets must be some list type");}
			| "tail" '(' expr ')'		{if(equalType($3,typeList(typeAny))) $$=$3;			else yyerror("expression in brackets must be some list type");}
			

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

bool FFLAG = false;
bool IFLAG = false;
bool OFLAG = false;


int yyerror(const char *msg){
	fprintf(stderr,"syntax error: %s\n",msg);
	exit(1);
}


SymbolEntry * stemp;

void parseArguments(int argc,char * argv[]){

	int i, fileArg=0;
	for(i=1;i<argc;i++){
		if(strcmp(argv[i],"-f")==0)
			FFLAG=true;
		else if(strcmp(argv[i],"-i")==0)
			IFLAG=true;
		else if(strcmp(argv[i],"-O")==0)
			OFLAG=true;
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
	if(FFLAG || IFLAG)
		filename="stdin";
	else
		filename = argv[fileArg];

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
	#define SYMBOLTABLE_SIZE 257
#endif
	initSymbolTable(SYMBOLTABLE_SIZE);

	/* Calling the syntax parser */
	return yyparse();

}
