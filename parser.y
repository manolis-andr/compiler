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
#include "intermediate.h"

/* Struct for remembering previous symbol table options, when we dig deeper into the symbols */
struct Memory{
	SymbolEntry *	func;
	Type			type;
	PassMode		ref;
	int				forward;
	SymbolEntry *	arg;
} mem;

/* checks if excessive brackets have been placed and returns type of array dereferene */
Type findArrayType(Type arrayType,int brackets)
{
	Type t = arrayType;
	while(t->refType!=NULL && brackets>0){
		t=t->refType;
		brackets--;
	}
	if(t->refType==NULL && brackets>0) 
		sserror("excessive brackets");
	else 
		return t;
}


%}

%union{
	Type type;
	const char * name;
	int val;
	struct expr_struct {
		SymbolEntry *	place;
		Type			type;
		List *			TRUE;
		List *			FALSE;
		bool			lval;
	} expr;
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
%token<val> T_int_const	
%token<val> T_char_const
%token<name> T_string

%type<expr> expr
%type<expr> atom
%type<type> type
%type<type> call
%type<type> array_cell
%type<val>	brackets
%type<val>	bracket_list

%left "or"
%left "and"
%nonassoc "not"		/* This is a unary operator, associativity has no meaning */
%nonassoc '=' "<>" '<' '>' "<=" ">=" 
%right '#'
%left '+' '-'
%left '*' '/' "mod"

%%

program		: {openScope();} func_def {closeScope();}

/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	BLOCK DEFINITION (FUNCTIONS)
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

func_def	: "def" {mem.forward=0;} header ':' def_list stmt_list "end" {closeScope();} ;

def_list	: func_def def_list 
			| func_decl def_list	
			| var_def def_list		
			| /* nothing */
			
			/* checks that T_id is uniquely defined in the current scope (not already in Symbol Table) inside newFunction */
header		: type T_id		{	mem.func = newFunction($2); 
								if(mem.forward==1) 
									forwardFunction(mem.func); 
								openScope();
								currentScope->returnType = $1;
							} 
				'(' formal_list ')' {endFunctionHeader(mem.func,$1);}	 
			| T_id			{	mem.func = newFunction($1); 
								if(mem.forward==1) 
									forwardFunction(mem.func); 
								openScope();
								currentScope->returnType = typeVoid;
							} 
				'(' formal_list ')' {endFunctionHeader(mem.func,typeVoid);}	
			;

formal_list	: formal formal_full | /* nothing */;
formal_full	: ';' formal formal_full | /* nothing */;

formal		: "ref" type	{mem.ref=PASS_BY_REFERENCE; mem.type=$2;}	id_par_list
			| type			{mem.ref=PASS_BY_VALUE;		mem.type=$1;}	id_par_list
			

			/* checks that T_id is uniquely defined in the current scope (not already in Symbol Table) */
id_par_list : T_id {if(lookupEntry($1,LOOKUP_CURRENT_SCOPE,false)!=NULL) ssmerror("duplicate declaration of identifier in current scope"); 
					newParameter($1,mem.type,mem.ref,mem.func);} 
				id_par_full ;
id_par_full : ',' T_id {if(lookupEntry($2,LOOKUP_CURRENT_SCOPE,false)!=NULL) ssmerror("duplicate declaration of identifier in current scope"); 
						 newParameter($2,mem.type,mem.ref,mem.func);} 
				id_par_full 
			| /* nothing */ 


/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	TYPES & VARIABLES
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

type		: "int"					{$$=typeInteger;}
			| "bool"				{$$=typeBoolean;}
			| "char"				{$$=typeChar;}
			| type '[' ']'			{$$=typeIArray($1);}
			| "list" '[' type ']'	{$$=typeList($3);}
			;

func_decl	: "decl"	{mem.forward=1;}	header ;

var_def		: type		{mem.type=$1;}		id_list ;


id_list		: T_id		{if(lookupEntry($1,LOOKUP_CURRENT_SCOPE,false)!=NULL) 
							ssmerror("duplicate declaration of identifier in current scope"); 
						 newVariable($1,mem.type);
						 #ifdef DEBUG
						 printf("var: %s\ttype: %s\n",$1,typeToStr(mem.type));
						 #endif
						 }
			   id_full 
			;
id_full		: ',' T_id	{if(lookupEntry($2,LOOKUP_CURRENT_SCOPE,false)!=NULL) 
							ssmerror("duplicate declaration of identifier in current scope"); 
						 newVariable($2,mem.type); 
						 #ifdef DEBUG
						 printf("var: %s\ttype: %s\n",$2,typeToStr(mem.type));
						 #endif
						} 
				id_full 
			| /* nothing */
			

/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	STATEMENTS
 * -------------------------------------------------------------------------------------------------------------------------------- */ 


stmt_list	: stmt stmt_full
stmt_full	: stmt stmt_full
			| /* nothing */;

stmt		: simple 
			/* check that this exit stmt is in a block (function) with a return type TYPE_VOID */
			| "exit"			{if(!equalType(currentScope->returnType,typeVoid)) sserror("exit statement no allowed in a non void block");}
			/* check that this return stmt is in a block (function) with a return type t same as the expr.type */ 
			| "return" expr		{if(!equalType(currentScope->returnType,$2.type)) sserror("return statement is of different type than epxected");}
			| if_clause 
			| for_clause
			;		

for_clause	: "for" simple_list ';' expr ';' simple_list ':' stmt_list "end" 
			/* check that expr has type bool */ 
			{if(!equalType($4.type,typeBoolean)) sserror("condition expression in for clause must be boolean");}

			/* check that expr has type bool, if an expression is evaluated true then we do not evaluate the other elif/else branches */ 
			/* the following of grammar allows the desired behaviour from is-clauses */
if_clause	: "if" expr {if(!equalType($2.type,typeBoolean)) ssmerror("condition expression in if must be boolean");} 
				':' stmt_list elsif_clause else_clause "end" ;

elsif_clause: "elsif" expr {if(!equalType($2.type,typeBoolean)) ssmerror("condition expression in elsif must be boolean");} 
				':' stmt_list elsif_clause 
			| /* nothing */;

else_clause	: "else" ':' stmt_list 
			| /* nothing */;


simple		: "skip" 
			| atom ":=" expr {	/* atom is l-value && expr.type=atom.type */
								if($1.lval==false)				sserror("expression in left of assigment must be an l-value");
								if(!equalType($1.type,$3.type))	sserror("type mismatch in assigment: left expr is %s while right is %s",
																		 typeToStr($1.type),typeToStr($3.type));
							 }  
			| call 
			;

simple_list	: simple simple_full ; 
simple_full	: ',' simple simple_full | /* nothing */



/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	FUNCTION CALLS
 * -------------------------------------------------------------------------------------------------------------------------------- */ 


			/* check that T_id is ENTRY_FUNCTION && check function call limitations */
call		: T_id '('			{	SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
									if(s->entryType!=ENTRY_FUNCTION) ssmerror("identifier is not a function");
									mem.arg=s->u.eFunction.firstArgument;
									mem.type=s->u.eFunction.resultType;
								}	
				expr_list ')'	{$$=mem.type;}
			| T_id '(' ')'		{	SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
									if(s->entryType!=ENTRY_FUNCTION) sserror("identifier is not a function");
									if(s->u.eFunction.firstArgument!=NULL) sserror("function expects more arguments");
									$$=s->u.eFunction.resultType;
								}	
			;

expr_list	: expr				{	if(mem.arg==NULL)								
										ssmerror("function expects less arguments");
									if(!equalType($1.type,mem.arg->u.eParameter.type))	
										ssmerror("type mismatch in function arguments: expected %s but found %s\n",
												 typeToStr(mem.arg->u.eParameter.type),typeToStr($1.type));
									if(mem.arg->u.eParameter.mode==PASS_BY_REFERENCE && $1.lval==false)			
										ssmerror("parameter pass is by reference but argument is not an l-value");
									mem.arg=mem.arg->u.eParameter.next;
								}
				expr_full
			;

expr_full	:',' expr			{	if(mem.arg==NULL)								
										ssmerror("function expects less arguments");
									if(!equalType($2.type,mem.arg->u.eParameter.type))	
										ssmerror("type mismatch in function arguments: expected %s but found %s\n",
												 typeToStr(mem.arg->u.eParameter.type),typeToStr($2.type));
									if(mem.arg->u.eParameter.mode==PASS_BY_REFERENCE && $2.lval==false)			
										ssmerror("parameter pass is by reference but argument is not an l-value");
									mem.arg=mem.arg->u.eParameter.next;
								}
				expr_full
			| /* nothing */		{	if(mem.arg!=NULL) sserror("function expects more arguments");}



/* -------------------------------------------------------------------------------------------------------------------------------- 
 * ATOMS & EXPRESSIONS
 * -------------------------------------------------------------------------------------------------------------------------------- */ 


atom		: T_id			{	SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
								switch(s->entryType){
									case(ENTRY_FUNCTION):	sserror("identifier is a function and is not called properly");
									case(ENTRY_VARIABLE):	$$.type=s->u.eVariable.type;
									case(ENTRY_PARAMETER):	$$.type=s->u.eParameter.type;
								}
								$$.lval=true;
								/*I*/$$.place=s;
							}
			| T_string		{$$.type=typeIArray(typeChar);	$$.lval=false;	SymbolEntry * s = newConstant(NULL,$$.type,$1);	/*I*/$$.place=s;} 
			| array_cell	{$$.type=$1;					$$.lval=true; }	/* we modified our grammar right here */
			| call			{$$.type=$1;					$$.lval=false;}
			;

array_cell	: T_id bracket_list		{	SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true);
										switch(s->entryType){
											case ENTRY_FUNCTION:	sserror("identifier for array dereferencing cannot be a function");
											case ENTRY_VARIABLE:	$$=findArrayType(s->u.eVariable.type,$2);
											case ENTRY_PARAMETER:	$$=findArrayType(s->u.eParameter.type,$2);
										}
										//printf("%s type: %s\n",$1,typeToStr(s->u.eVariable.type));
									} 
bracket_list: '[' expr ']' brackets {$$=$4+1;	if(!equalType($2.type,typeInteger)) sserror("expression in brackets must be a non negative integer");};
brackets	: '[' expr ']' brackets {$$=$4+1;	if(!equalType($2.type,typeInteger)) sserror("expression in brackets must be a non negative integer");}
			| /* nothing */			{$$=0; }	
										
						

/* check TYPES for all of the expression forms below */
expr		: atom				{$$.type=$1.type;		$$.lval=$1.lval;/*I*/$$.place = $1.place;}
			| T_int_const		{$$.type=typeInteger;	$$.lval=false;	/*I*/$$.place = newConstant(NULL,typeInteger,$1);	}
			| T_char_const		{$$.type=typeChar;		$$.lval=false;  /*I*/$$.place = newConstant(NULL,typeChar,$1);		}		
			| '(' expr ')'		{$$.type=$2.type;		$$.lval=false;  /*I*/$$.place=$2.place; } 
			| '+' expr			{if(equalType($2.type,typeInteger)) {$$.type=typeInteger; $$.lval=false; $$.place=$2.place;}	else sserror("operator takes int");}
			| '-' expr			{if(!equalType($2.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 $$.lval=false;
								 /*I*/SymbolEntry * w = newTemporary(typeInteger);
								 genquad("-",oS(newConstant(NULL,typeInteger,0)),oS($2.place),oS(w));
								 $$.place=w; /*I*/
								}	
			| expr '+' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator work only on int operands");
								 $$.type=typeInteger; 
								 $$.lval=false;
								 /*I*/SymbolEntry * w = newTemporary(typeInteger);
								 genquad("+",oS($1.place),oS($3.place),oS(w));
								 $$.place=w; /*I*/
								}	
			| expr '-' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 $$.lval=false;
								 /*I*/SymbolEntry * w = newTemporary(typeInteger);
								 genquad("-",oS($1.place),oS($3.place),oS(w));
								 $$.place=w; /*I*/
								}	
			| expr '*' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 $$.lval=false;
								 /*I*/SymbolEntry * w = newTemporary(typeInteger);
								 genquad("*",oS($1.place),oS($3.place),oS(w));
								 $$.place=w; /*I*/
								}	
			| expr '/' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 $$.lval=false;
								 /*I*/SymbolEntry * w = newTemporary(typeInteger);
								 genquad("/",oS($1.place),oS($3.place),oS(w));
								 $$.place=w; /*I*/
								}	
			| expr "mod" expr	{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 $$.lval=false;
								 /*I*/SymbolEntry * w = newTemporary(typeInteger);
								 genquad("-",oS($1.place),oS($3.place),oS(w));
								 $$.place=w; /*I*/
								}	
			| expr '=' expr		{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 %s arg2 %s",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.lval=false;
								 /*I*/$$.TRUE = makelist(quadNext);
								 genquad("=",oS($1.place),oS($3.place),oSTAR);
								 $$.FALSE = makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);/*I*/
								 }
			| expr "<>" expr	{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 %s arg2 %s",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.lval=false;			
								 /*I*/$$.TRUE = makelist(quadNext);
								 genquad("<>",oS($1.place),oS($3.place),oSTAR);
								 $$.FALSE = makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);/*I*/
								 }

			| expr '<' expr		{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 %s arg2 %s",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.lval=false;			
								 /*I*/$$.TRUE = makelist(quadNext);
								 genquad("<",oS($1.place),oS($3.place),oSTAR);
								 $$.FALSE = makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);/*I*/
								 }

			| expr '>' expr		{if(!equalType($1.type,$3.type))
									sserror("type mismatch between operands: arg1 %s arg2 %s",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.lval=false;			
								 /*I*/$$.TRUE = makelist(quadNext);
								 genquad(">",oS($1.place),oS($3.place),oSTAR);
								 $$.FALSE = makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);/*I*/
								 }

			| expr "<=" expr	{if(!equalType($1.type,$3.type))
									sserror("type mismatch between operands: arg1 %s arg2 %s",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.lval=false;			
								 /*I*/$$.TRUE = makelist(quadNext);
								 genquad("<=",oS($1.place),oS($3.place),oSTAR);
								 $$.FALSE = makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);/*I*/
								 }

			| expr ">=" expr	{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 %s arg2 %s",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.lval=false;			
								 /*I*/$$.TRUE = makelist(quadNext);
								 genquad(">=",oS($1.place),oS($3.place),oSTAR);
								 $$.FALSE = makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);/*I*/
								 }

			| "true"			{$$.type=typeBoolean;	$$.lval=false;	$$.place=newConstant("true",typeBoolean,"true");}
			| "false"			{$$.type=typeBoolean;	$$.lval=false;	$$.place=newConstant("false",typeBoolean,"false");}
			| "not" expr		{$$.type=typeBoolean;	$$.lval=false;}

			| expr "and" expr	{if(equalType($1.type,typeBoolean) && equalType($3.type,typeBoolean)) {$$.type=typeBoolean; $$.lval=false;} 
								 else sserror("operator takes boolean operands");}

			| expr "or" expr	{if(equalType($1.type,typeBoolean) && equalType($3.type,typeBoolean)) {$$.type=typeBoolean; $$.lval=false;}
								 else sserror("operator takes boolean operands");}

			| "new" type '[' expr ']'	{if(equalType($4.type,typeInteger)) {$$.type=typeIArray($2); $$.lval=false;}
										 else sserror("array size must be integer whereas expression in brackets is %s",typeToStr($4.type));}

			| expr '#' expr				{if(equalType($3.type,typeList(typeAny)) && equalType($1.type,$3.type->refType)) 
											{$$.type=$3.type; $$.lval=false;}
										 else sserror("type mismatch in list construction (head: %s tail: %s)",typeToStr($1.type),typeToStr($1.type));}

			| "nil"						{$$.type=typeList(typeAny);	$$.lval=false;}

			| "nil?" '(' expr ')'		{if(equalType($3.type,typeList(typeAny))) {$$.type=typeBoolean; $$.lval=false;}
										 else sserror("expression in brackets must be some list type");}

			| "head" '(' expr ')'		{if(equalType($3.type,typeList(typeAny))) {$$.type=$3.type->refType; $$.lval=false;}
										 else sserror("expression in brackets must be some list type but is %s",typeToStr($3.type));}

			| "tail" '(' expr ')'		{if(equalType($3.type,typeList(typeAny))) {$$.type=$3.type;}			 
										 else sserror("expression in brackets must be some list type");}
			

/* function call limitations 
 * 1. T_id name of the function exists in current scope
 * 2. types of arguments passed are of the same type
 * 3. if arguments are passed by reference, they must be valid l-values
 * /

/* In each T_id allocation we must check if the specific T_id is uniqe = 1st time to be created. ONLY in T_id ALLOCAATION */


%%

extern FILE *	yyin;
extern char *	yytext;

const char *	filename;

bool FFLAG = false;
bool IFLAG = false;
bool OFLAG = false;

/* For syntax errors: called implicitly by parser */
int yyerror(const char *msg){
	fprintf(stderr, "%s:%d: ", filename, linecount);
	fprintf(stderr,"syntax error: %s\n",msg);
	exit(1);
}

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
