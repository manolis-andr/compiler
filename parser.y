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
#include "final.h"

/* Struct for remembering previous symbol table options, when we dig deeper into the symbols */
struct Memory{
	SymbolEntry *	func;
	Type			type;
	PassMode		ref;
	int				forward;
	SymbolEntry *	arg;
	Operand			place;
	int				loopLabel;
	int				condLabel;
	List *			lnext;
	List *			lastFalse;
	List *			endif;
} mem;


typedef struct c_pair{
	SymbolEntry *	func;
	SymbolEntry *	arg;
	struct c_pair *	next;
} c_pair;

c_pair * c_stack = NULL;

c_push(SymbolEntry * func, SymbolEntry * arg)
{
	c_pair * n = (c_pair *) new(sizeof(c_pair));
	n->func = func;
	n->arg	= arg;
	n->next = c_stack;
	c_stack = n;
}

c_pop(){
	if(c_stack==NULL) internal("attempt to pop from empty stack");
	c_pair * temp = c_stack;
	c_stack = c_stack->next;
	delete(temp);
}


SymbolEntry * c_getFunc() {return c_stack->func;}
SymbolEntry * c_getArg()  {return c_stack->arg;}
void c_setArg(SymbolEntry * arg) {c_stack->arg = arg;}



/* *********************** */

#ifndef LF_PARAM_NUM_MAX
	#define LF_PARAM_NUM_MAX 2
#endif
#ifndef LF_FUNC_NUM
	#define LF_FUNC_NUM 15
#endif


typedef struct LibFuncParam_tag {
	char *		name;
	Type		type;
	PassMode	passMode;
} LibFuncParam;

typedef struct LibFunc_tag{
	char *			name;
	Type			returnType;
	int				paramNum;
	LibFuncParam    paramList[LF_PARAM_NUM_MAX];
} LibFunc;



void declareLF(LibFunc lf)
{
	//excessive check for internal consistency
	if(lookupEntry(lf.name,LOOKUP_ALL_SCOPES,false)!=NULL) internal("LibFunc: run-time library function %s duplicate definition",lf.name);
	SymbolEntry * func = newFunction(lf.name);
	forwardFunction(func);
	openScope();
	currentScope->returnType = lf.returnType;
	//func->u.eFunction.firstQuad=??
	int i;
	for(i=0;i<lf.paramNum;i++){
		LibFuncParam * p = &lf.paramList[i];
		//excessive cheks for internal consistency
		if(p==NULL) internal("LibFunc: run-time library function %s expects more parameters",lf.name);
		if(lookupEntry(p->name,LOOKUP_CURRENT_SCOPE,false)!=NULL) internal("LibFunc: run-time library function %s has duplicate parameter %s",lf.name,p->name);
		newParameter(p->name,p->type,p->passMode,func);
	}
	endFunctionHeader(func,lf.returnType);
}


void declareAllLibFunc()
{
	// here we declare all the run-time library functions
	LibFunc libraryFunctions [LF_FUNC_NUM] = {
		{ "puti",	typeVoid,		1, { {"n", typeInteger,			PASS_BY_VALUE}, } },
		{ "putb",	typeVoid,		1, { {"b", typeBoolean,			PASS_BY_VALUE}, } },
		{ "putc",	typeVoid,		1, { {"c", typeChar,			PASS_BY_VALUE}, } },
		{ "puts",	typeVoid,		1, { {"s", typeIArray(typeChar),PASS_BY_VALUE}, } },
		{ "geti",	typeInteger,	0, NULL											  },
		{ "getb",	typeBoolean,	0, NULL 										  },
		{ "getc",	typeChar,		0, NULL 										  },
		{ "gets",	typeVoid,		2, { {"n", typeInteger,			PASS_BY_VALUE}, 
										 {"s", typeIArray(typeChar),PASS_BY_VALUE}, } },
		{ "abs",	typeInteger,	1, { {"n", typeInteger,			PASS_BY_VALUE}, } },
		{ "ord",	typeInteger,	1, { {"c", typeChar,			PASS_BY_VALUE}, } },
		{ "chr",	typeChar,		1, { {"n", typeInteger,			PASS_BY_VALUE}, } },
		{ "strlen",	typeInteger,	1, { {"s", typeIArray(typeChar),PASS_BY_VALUE}, } },
		{ "strcmp",	typeInteger,	2, { {"s1",typeIArray(typeChar),PASS_BY_VALUE},  
										 {"s2",typeIArray(typeChar),PASS_BY_VALUE}, } },
		{ "strcpy",	typeVoid,		2, { {"trg",typeIArray(typeChar),PASS_BY_VALUE}, 
										 {"src",typeIArray(typeChar),PASS_BY_VALUE},} },
		{ "strcat",	typeVoid,		2, { {"trg",typeIArray(typeChar),PASS_BY_VALUE}, 
										 {"src",typeIArray(typeChar),PASS_BY_VALUE},} },
	};

	int i;
	for(i=0;i<LF_FUNC_NUM;i++)
		declareLF(libraryFunctions[i]);
}


%}

%union{
	Type type;
	const char * name;
	int val;
	struct expr_tag {
		Type		type;
		bool		lval;
		bool		cond;
		Operand		place;
		List *		TRUE;
		List *		FALSE;
	} expr;
	struct rval_tag {
		Type		type;
		bool		cond;
		Operand		place;
		List *		TRUE;
		List *		FALSE;
	} rval;
	struct atom_tag {
		Type		type;
		Operand		place;
		bool		lval;
	}atom;
	struct call_tag {
		Type		type;
		Operand		place;
	}call;
	struct stmt_tag {
		List *			NEXT;
	}stmt;
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

%type<name> header

%type<type> type

%type<stmt> stmt
%type<stmt> stmt_list
%type<stmt> stmt_full
%type<stmt> if_clause
%type<stmt> for_clause

%type<expr> expr
%type<rval> rval

%type<atom> atom 

%type<call> call




%left "or"
%left "and"
%nonassoc "not"		/* This is a unary operator, associativity has no meaning */
%nonassoc '=' "<>" '<' '>' "<=" ">=" 
%right '#'
%left '+' '-'
%left '*' '/' "mod"


%%

program		: {openScope(); declareAllLibFunc();} func_def { printQuads(); closeScope();}

/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	BLOCK DEFINITION (FUNCTIONS)
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

func_def	: "def"	{mem.forward=0;} header ':'	
			  def_list							{genquad("unit",oU($3),o_,o_); }
			  stmt_list 
			  "end"								{backpatch($7.NEXT,quadNext); 
												 genquad("endu",oU($3),o_,o_);  
												 printQuads(); //print quads
												#ifdef DEBUG
												 printf("scope %s closes\n",$3);
												#endif
												 closeScope();} ;

def_list	: func_def def_list 
			| func_decl def_list	
			| var_def def_list		
			| /* nothing */
			
			/* checks that T_id is uniquely defined in the current scope (not already in Symbol Table) inside newFunction */
header		: type T_id		{	mem.func = newFunction($2); 
								if(mem.forward==1) 
									forwardFunction(mem.func);
								openScope();
								#ifdef DEBUG
								printf("scope %s opens\n",$2);
								#endif
								currentScope->returnType = $1;
							} 
			  '(' formal_list ')' {endFunctionHeader(mem.func,$1); $$=$2; mem.func->u.eFunction.firstQuad=quadNext;}
			| T_id			{	mem.func = newFunction($1); 
								if(mem.forward==1) 
									forwardFunction(mem.func); 
								openScope();
								#ifdef DEBUG
								printf("scope %s opens\n",$1);
								#endif
								currentScope->returnType = typeVoid;
							} 
			  '(' formal_list ')' {endFunctionHeader(mem.func,typeVoid); $$=$1; mem.func->u.eFunction.firstQuad=quadNext;}	
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

																												/* Attributes: type */
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

																												/* Attributes: NEXT */
stmt_list	: stmt {mem.lnext=$1.NEXT;}			stmt_full {$$.NEXT=$3.NEXT;}
stmt_full	: {backpatch(mem.lnext,quadNext);}	stmt	  {mem.lnext=$2.NEXT;} stmt_full {$$.NEXT=$4.NEXT;}
			| /* nothing */{$$.NEXT=mem.lnext;}
			;

stmt		: simple			{$$.NEXT=emptylist();}
								/* check that this exit stmt is in a block (function) with a return type TYPE_VOID */
			| "exit"			{if(!equalType(currentScope->returnType,typeVoid)) sserror("exit statement no allowed in a non void block"); 
								 genquad("ret",o_,o_,o_);
								 $$.NEXT=emptylist();}
								/* check that this return stmt is in a block (function) with a return type t same as the expr.type */ 
			| "return" expr		{if(!equalType(currentScope->returnType,$2.type)) sserror("return statement is of different type than epxected");
								 if($2.cond) $2.place = evaluateCondition($2.TRUE,$2.FALSE);
								 genquad("retv",$2.place,o_,o_);
								 genquad("ret",o_,o_,o_);
								 $$.NEXT=emptylist();}
			| if_clause			{$$.NEXT=$1.NEXT;} 
			| for_clause		{$$.NEXT=$1.NEXT;}
			;		


for_clause	: "for" simple_list ';' {mem.condLabel=quadNext;}
				expr ';'			{if(!equalType($5.type,typeBoolean)) sserror("second part of 'for' clause must be a boolean expression");
									 if(!$5.cond) {ListPair l = createCondition($5.place); $5.TRUE=l.TRUE; $5.FALSE=l.FALSE;}
									 mem.loopLabel=quadNext;}	
				simple_list ':'		{genquad("jump",o_,o_,oL(mem.condLabel));	backpatch($5.TRUE,quadNext);}
				stmt_list			{backpatch($11.NEXT,mem.loopLabel);			genquad("jump",o_,o_,oL(mem.loopLabel));}
				"end"				{$$.NEXT=$5.FALSE;} 



/* ----- IF ---- */

			/* the following form of grammar allows the desired precedence behaviour from if-clauses */
if_clause	: "if" expr			{if(!equalType($2.type,typeBoolean)) sserror("condition of 'if' clause must be a boolean expression");
								 if(!$2.cond) {ListPair l = createCondition($2.place); $2.TRUE=l.TRUE; $2.FALSE=l.FALSE;}
								 backpatch($2.TRUE,quadNext);		mem.lastFalse=$2.FALSE;
								} 
				':' stmt_list	{mem.endif=makelist(quadNext);		genquad("jump",o_,o_,oSTAR);	mem.endif=merge(mem.endif,$5.NEXT);}
				elsif_clause 
				else_clause 
				"end"			{$$.NEXT=merge(mem.endif,mem.lastFalse);}
			;

elsif_clause: "elsif"			{backpatch(mem.lastFalse,quadNext);}
				expr			{if(!equalType($3.type,typeBoolean)) sserror("condition of 'if' clause must be a boolean expression");
								 if(!$3.cond) {ListPair l = createCondition($3.place); $3.TRUE=l.TRUE; $3.FALSE=l.FALSE;}
								 backpatch($3.TRUE,quadNext);					mem.lastFalse=$3.FALSE;
								}
				':' stmt_list	{mem.endif=merge(mem.endif,makelist(quadNext));	genquad("jump",o_,o_,oSTAR);	mem.endif=merge(mem.endif,$6.NEXT);}
				elsif_clause 
			| /* nothing */;

else_clause	: "else" ':'		{backpatch(mem.lastFalse,quadNext);				mem.lastFalse=emptylist();}
				stmt_list		{mem.endif=merge(mem.endif,makelist(quadNext));	genquad("jump",o_,o_,oSTAR);	mem.endif=merge(mem.endif,$4.NEXT);}
			| /* nothing */

/* ------------- */


/* all simple commands have NEXT=emptylist() so w do not bother assigning NEXT attribute to simple or simple lists*/

simple		: "skip"			
								 /* atom is l-value && expr.type=atom.type */
			| atom ":=" expr	{if(!$1.lval) sserror("expression in the left of asssigment is not an lvalue as it should be");
								 if(!equalType($1.type,$3.type))	
									 sserror("type mismatch in assigment: left expr is %s while right is %s",typeToStr($1.type),typeToStr($3.type));
								 if($3.cond) $3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 genquad(":=",$3.place,o_,$1.place);
								}  
			| call				
			;

simple_list	: simple simple_full 
simple_full	: ',' simple simple_full | /* nothing */



/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	FUNCTION CALLS
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

																										/* Attributes: type, place */

			/* check that T_id is ENTRY_FUNCTION && check function call limitations */
call		: T_id '('			{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
								 if(s->entryType!=ENTRY_FUNCTION) ssmerror("identifier is not a function");
								 c_push(s,s->u.eFunction.firstArgument);
								}	
				expr_list ')'	{SymbolEntry *s = c_getFunc(); 
								 if(!equalType(s->u.eFunction.resultType,typeVoid)){
									 SymbolEntry * w = newTemporary(s->u.eFunction.resultType);
									 genquad("par",oRET,oS(w),o_);
									 $$.place= oS(w);
									 }
								 else $$.place=NULL;
								 genquad("call",o_,o_,oU(s->id)); 
								 $$.type=s->u.eFunction.resultType;
								 c_pop();
								}
			| T_id '(' ')'		{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
								 if(s->entryType!=ENTRY_FUNCTION)		sserror("identifier is not a function");
								 if(s->u.eFunction.firstArgument!=NULL) sserror("function %s expects more arguments",s->id);
								 if(!equalType(s->u.eFunction.resultType,typeVoid)){
									 SymbolEntry * w = newTemporary(s->u.eFunction.resultType);
									 genquad("par",oRET,oS(w),o_);
									 $$.place= oS(w);
									 }
								 else $$.place=NULL;
								 genquad("call",o_,o_,oU(s->id)); 
								 $$.type=s->u.eFunction.resultType;
								}	
			

expr_list	: expr				{SymbolEntry * arg = c_getArg();
								 if(arg==NULL)								
									ssmerror("function %s expects less arguments",c_getFunc()->id);
								 if(!equalType($1.type,arg->u.eParameter.type))	
									ssmerror("type mismatch in function arguments: expected %s but found %s\n",
											 typeToStr(arg->u.eParameter.type),typeToStr($1.type));
								 if($1.cond) $1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $1.lval==false)			
									ssmerror("parameter pass is by reference but argument is not an l-value");
								 else if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $1.lval==true)
									genquad("par",oR,$1.place,o_);
							 	 else if (arg->u.eParameter.mode==PASS_BY_VALUE)
									genquad("par",oV,$1.place,o_); 
								 else internal("unmatched parameter case");
								 c_setArg(arg->u.eParameter.next);
								}
				expr_full
			

expr_full	:',' expr			{SymbolEntry * arg = c_getArg();
								 if(arg==NULL)								
									ssmerror("function %s expects less arguments",c_getFunc()->id);
								 if(!equalType($2.type,arg->u.eParameter.type))	
									ssmerror("type mismatch in function arguments: expected %s but found %s\n",
											 typeToStr(arg->u.eParameter.type),typeToStr($2.type));
								 if($2.cond) $2.place = evaluateCondition($2.TRUE,$2.FALSE);
								 if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $2.lval==false)			
									ssmerror("parameter pass is by reference but argument is not an l-value");
								 else if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $2.lval==true)
									genquad("par",oR,$2.place,o_);
							 	 else if (arg->u.eParameter.mode==PASS_BY_VALUE) 
									genquad("par",oV,$2.place,o_);
								 else internal("unmatched parameter case");
								 c_setArg(arg->u.eParameter.next);
								}
				expr_full		
			| /* nothing */		{if(c_getArg()!=NULL) sserror("function %s expects more arguments",c_getFunc());}



/* -------------------------------------------------------------------------------------------------------------------------------- 
 * ATOMS
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

																									/* Attributes: type, place, lval */


atom		: T_id				{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
								switch(s->entryType){
									case(ENTRY_FUNCTION):	sserror("identifier is a function and is not called properly");
									case(ENTRY_VARIABLE):	$$.type=s->u.eVariable.type;
									case(ENTRY_PARAMETER):	$$.type=s->u.eParameter.type;
								}
								$$.place=oS(s);
								$$.lval=true;
								}
			| T_string			{$$.type=typeIArray(typeChar); /*FIXME: maybe here we must use pure sized array*/
								 SymbolEntry * s = newConstant($1,$$.type,$1);
								 $$.place=oS(s);
								 $$.lval=false;
								}
			| call				{$$.type=$1.type;
								 $$.place=$$.place;
								 $$.lval=false;
								}
			| atom '[' expr ']' {if(!equalType($1.type,typeIArray(typeAny))) sserror("excessive brackets");
								 if(!equalType($3.type,typeInteger)) sserror("expression in brackets must be integer");
								 $$.type=($1.type)->refType;
								 SymbolEntry * w = newTemporary(typePointer($1.type));
								 genquad("array",$1.place,$3.place,oS(w));
								 $$.place=oD(w);
								 $$.lval=$1.lval;
								}
								 

/* -------------------------------------------------------------------------------------------------------------------------------- 
 * EXPRESSIONS 
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

																				/* Attributes:  type, cond, place, lval, TRUE, FALSE
																								type, cond, place, TRUE, FALSE		*/

/* check TYPES for all of the expression forms below */
expr		: atom				{$$.type=$1.type;	$$.lval=$1.lval;$$.place=$1.place;	$$.cond=false;	}
			| rval				{$$.type=$1.type;	$$.lval=false;	$$.place=$1.place;	$$.cond=$1.cond;}
			
rval:		 T_int_const		{$$.type=typeInteger;	$$.place = oS( newConstant(NULL,typeInteger,$1) );	}
			| T_char_const		{$$.type=typeChar;		$$.place = oS( newConstant(NULL,typeChar,$1)    );	}		
			| '(' expr ')'		{$$.type=$2.type;
								 $$.cond=$2.cond;
								 if($2.cond)	{$$.TRUE=$2.TRUE;	$$.FALSE=$2.FALSE;} 
								 else			 $$.place=$2.place; 
								} 
			| '+' expr			{if(!equalType($2.type,typeInteger)) sserror("operator takes int");
								 $$.type=typeInteger;	$$.place=$2.place;	$$.cond=false;
								}
			| '-' expr			{if(!equalType($2.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad("-",oS(newConstant("0",typeInteger,0)),$2.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '+' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator work only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad("+",$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '-' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad("-",$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '*' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad("*",$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '/' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad("/",$1.place,$3.place,oS(w));
								 $$.place=oS(w); 
								 $$.cond=false;
								}	
			| expr "mod" expr	{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad("-",$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}

			| expr '=' expr		{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: 'arg1 %s' and arg2 '%s'",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.cond=true;
								 if($1.cond)	$1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if($3.cond)	$3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 $$.TRUE=makelist(quadNext);
								 genquad("=",$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);
								}
			| expr "<>" expr	{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 '%s' and arg2 '%s'",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.cond=true;
								 if($1.cond)	$1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if($3.cond)	$3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 $$.TRUE=makelist(quadNext);
								 genquad("<>",$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);
								}
			| expr '<' expr		{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 '%s' and arg2 '%s'",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.cond=true;
								 if($1.cond)	$1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if($3.cond)	$3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 $$.TRUE=makelist(quadNext);
								 genquad("<",$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);
								}
			| expr '>' expr		{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 '%s' and arg2 '%s'",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.cond=true;
								 if($1.cond)	$1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if($3.cond)	$3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 $$.TRUE=makelist(quadNext);
								 genquad(">",$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);
								}
			| expr "<=" expr	{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 '%s' and arg2 '%s'",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.cond=true;
								 if($1.cond)	$1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if($3.cond)	$3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 $$.TRUE=makelist(quadNext);
								 genquad("<=",$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);
								}	
			| expr ">=" expr	{if(!equalType($1.type,$3.type)) 
									sserror("type mismatch between operands: arg1 '%s' and arg2 '%s'",typeToStr($1.type),typeToStr($3.type));
								 if((!equalType($1.type,typeInteger)) && (!equalType($1.type,typeChar)) && (!equalType($1.type,typeBoolean)))
									sserror("comparison allowed only between basic types");
								 $$.type=typeBoolean;
								 $$.cond=true;
								 if($1.cond)	$1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if($3.cond)	$3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 $$.TRUE=makelist(quadNext);
								 genquad(">=",$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad("jump",o_,o_,oSTAR);
								}

			| "not" expr		{if(!equalType($2.type,typeBoolean)) sserror("operator 'not' can be used only on boolean expression");
								 if(!$2.cond)	{ ListPair l = createCondition($2.place);	$2.TRUE=l.TRUE;	$2.FALSE=l.FALSE;	}
								 $$.TRUE=$2.FALSE;	
								 $$.FALSE=$2.TRUE;
								 $$.type=typeBoolean;
								 $$.cond=true;
								}

			| expr "and"		{if(!equalType($1.type,typeBoolean)) sserror("operator 'and' can be used only on boolean expression"); 
								 if(!$1.cond) { ListPair l = createCondition($1.place);		$1.TRUE=l.TRUE;	$1.FALSE=l.FALSE;	}
								 backpatch($1.TRUE,quadNext);
								} 
			  expr				{if(!equalType($4.type,typeBoolean)) sserror("operator 'and' can be used only on boolean expression"); 
								 if(!$4.cond) { ListPair l = createCondition($4.place);		$4.TRUE=l.TRUE;	$4.FALSE=l.FALSE;	}
								 $$.FALSE=merge($1.FALSE,$4.FALSE);		
								 $$.TRUE=$4.TRUE;	
								 $$.type=typeBoolean;
								 $$.cond=true; 
								}

			| expr "or"			{if(!equalType($1.type,typeBoolean)) sserror("operator 'or' can be used only on boolean expression"); 
								 if(!$1.cond) { ListPair l = createCondition($1.place);		$1.TRUE=l.TRUE;	$1.FALSE=l.FALSE;	}
								 backpatch($1.FALSE,quadNext);
								}
			  expr				{if(!equalType($4.type,typeBoolean)) sserror("operator 'or' can be used only on boolean expression"); 
								 if(!$4.cond) { ListPair l = createCondition($4.place);		$4.TRUE=l.TRUE;	$4.FALSE=l.FALSE;	}
								 $$.TRUE=merge($1.TRUE,$4.TRUE);		
								 $$.FALSE=$4.FALSE;	
								 $$.type=typeBoolean;
								 $$.cond=true;
								}

			| "true"			{$$.type=typeBoolean;	$$.place=oS(newConstant("true",typeBoolean,true));	$$.cond=false;}
			| "false"			{$$.type=typeBoolean;	$$.place=oS(newConstant("false",typeBoolean,false));$$.cond=false;}

			| "new" type '[' expr ']'	{if(!equalType($4.type,typeInteger))  
											sserror("array size must be integer whereas expression in brackets is %s",typeToStr($4.type));
										 $$.type=typeIArray($2); 
										 $$.place=oS(newTemporary($$.type));
										 $$.cond=false;
										}


			| expr '#' expr				{if(equalType($3.type,typeList(typeAny)) && equalType($1.type,$3.type->refType)) 
											$$.type=$3.type; 
										 else sserror("type mismatch in list construction (head: %s tail: %s)",typeToStr($1.type),typeToStr($1.type));}
										/* FIXME: ecaluateCondition for expr here */

			| "nil"						{$$.type=typeList(typeAny);}

			| "nil?" '(' expr ')'		{if(equalType($3.type,typeList(typeAny))) {$$.type=typeBoolean; }
										 else sserror("expression in brackets must be some list type");}

			| "head" '(' expr ')'		{if(equalType($3.type,typeList(typeAny))) {$$.type=$3.type->refType; }
										 else sserror("expression in brackets must be some list type but is %s",typeToStr($3.type));}

			| "tail" '(' expr ')'		{if(equalType($3.type,typeList(typeAny))) {$$.type=$3.type;}			 
										 else sserror("expression in brackets must be some list type");}
			


/* function call limitations 
 * 1. T_id name of the function exists in current scope
 * 2. types of arguments passed are of the same type
 * 3. if arguments are passed by reference, they must be valid l-values
 * /

/* In each T_id allocation we must check if the specific T_id is uniqe = 1st time to be created. ONLY in T_id ALLOCAATION */


/* =================================================================================================================================== */
/* =================================================================================================================================== */

%%

extern FILE *	yyin;
FILE *	iout;
FILE *	fout;


const char *	filename;




/* For syntax errors: called implicitly by parser */
int yyerror(const char *msg){
	fprintf(stderr, "%s:%d: ", filename, linecount);
	fprintf(stderr,"syntax error: %s\n",msg);
	exit(SYNTAX_ERRNUM);
}

void parseArguments(int argc,char * argv[]){

	bool FFLAG = false; 
	bool IFLAG = false;
	bool OFLAG = false;

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
	else{
		filename = argv[fileArg];
		yyin = fopen(filename,"r"); //Open file and redirect yylex to it
		if(yyin==NULL) fatal("filename %s is not valid. The file cannot be found.",filename);
	}

	/* FIXME: cleaning is not handled properly */
	#define EXTENSION_SIZE 5
	unsigned int size = strlen(filename) + EXTENSION_SIZE; 
	char fclean[size], buf[size];
	strcpy(fclean,filename);
	//fclean[strchr(fclean,'.')-fclean]='\0';

	/* Intermediate Code Filename Sepcification */ 
	if(!IFLAG){
		sprintf(buf,"%s.imm",fclean);
		iout = fopen(buf,"w");
	}else
		iout = stdout;
	
	/* Final Code Filename Sepcification */ 
	if(!FFLAG){
		sprintf(buf,"%s.asm",fclean);
		fout = fopen(buf,"w");
	}else
		fout = stdout;
}


int main(int argc, char * argv[]){

	fout = stdout;
	//skeletonBegin();
	//skeletonEnd();

	/* Arguments parsing */
	parseArguments(argc,argv);

	/* Initializing Symbol Table  */
#ifndef SYMBOLTABLE_SIZE
	#define SYMBOLTABLE_SIZE 257
#endif
	initSymbolTable(SYMBOLTABLE_SIZE);

	/* Calling the syntax parser */
	return yyparse();

}
