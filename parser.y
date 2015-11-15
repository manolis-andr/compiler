%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>

#include "symbol.h"
#include "error.h"
#include "general.h"
#include "intermediate.h"

#define SYMBOLTABLE_SIZE 3

//if interest in intermediate code only, define in a dummy way all the public functions of final.c 
#ifndef INTERMEDIATE
	#include "final.h"
#else
	void printFinal() { static bool flag = true;	if(flag) {fprintf(stderr,"Intermediate code only. Make-option INTERMEDIATE=1\n"); flag=!flag;} }
	void skeletonBegin(const char * c) {;}
	void skeletonEnd() {;}
#endif


/* -------------------------------------------------------------
   -------------------------- Datatypes ------------------------
   ------------------------------------------------------------- */

/* Generic Stack and Queue datatypes		*/
/* ---------------------------------------- */

/* generic node used in Stack and Queue*/
typedef struct genNode_tag {
	void *					data;
	struct genNode_tag *	next;
} genNode;

struct Stack_tag {
	genNode *	top;
	size_t		elementSize;
};

typedef struct Stack_tag * Stack;

struct Queue_tag{
	genNode *	first;
	genNode *	last;
	size_t		elementSize;
}; 

typedef struct Queue_tag * Queue;


/* Generic Stack Functions */

Stack newStack(size_t elementSize) 
{	
	Stack s = new(sizeof(struct Stack_tag));
	s->top = NULL;
	s->elementSize = elementSize;
	return s;
}

void push(Stack stack)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = new(stack->elementSize);
	n->next = stack->top;
	stack->top = n;
}

void pop(Stack stack)
{
	if(stack->top==NULL) internal("attempt to pop from empty stack");
	genNode * temp = stack->top;
	stack->top = stack->top->next;
	delete(temp->data);
	delete(temp);
}

void * top(Stack stack)	
{
	if(stack->top==NULL) fatal("attempt to access empty stack"); 
	return stack->top->data;
}


/* Generic Queue Functions */

Queue newQueue(size_t elementSize) 
{
	Queue q = new(sizeof(struct Queue_tag));
	q->first = q->last = NULL; 
	q->elementSize = elementSize;
	return q;
}

void addFirst(Queue queue)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = new(queue->elementSize);
	if(queue->first==NULL){
		n->next = NULL;
		queue->last = n;
	}else
		n->next = queue->first;
	queue->first = n;
}

void addLast(Queue queue)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = new(queue->elementSize);
	n->next = NULL;
	if(queue->last==NULL){
		queue->first = n;
	}else
		queue->last->next = n;
	queue->last = n;
}

void * getFirst(Queue q) 
{ 
	if(q->first==NULL) fatal("attempt to access empty queue");
	return q->first->data;
}

void * getLast(Queue q) 
{ 
	if(q->last==NULL) fatal("attempt to access empty queue");
	return q->last->data;
}

void * removeFirst(Queue q)
{
	if(q->first==NULL) fatal("attempt to access empty queue");
	void * data = q->first->data;
	genNode * temp = q->first;
	q->first = q->first->next;
	if(q->first==NULL) q->last=NULL; //queue empty
	delete(temp);
	return data;
}

bool isEmpty(Queue q) {return (q->first==NULL); }


/* Helper datatypes (structs & functions) for temporary saving of values */
/* --------------------------------------------------------------------- */

/* Struct for remembering previous symbol settings, when we dig deeper into the symbols 
 * ONLY for sequential symbol traversal (e.g. stmt), NOT for recursive traversal / nested symbols (e.g. if,for,call)
 */
struct Memory{
	SymbolEntry *	func;
	Type			type;
	PassMode		ref;
	int				forward;
	List *			lnext;
};


/* For reqursive traversal (nested symbols) we use Stacks.
 * Symbols that can be nested: 
 * - call (and parameters expressions) 
 * - if_clause
 * - for_clause
 */

/* Helper Nodes to be used as data in generic datatypes Queue and Stack */ 

typedef struct ifNode_tag {
	List *	endif;
	List *	lastFalse;
} ifNode;

typedef struct forNode_tag {
	int loopLabel;
	int condLabel;
} forNode;

typedef struct parNode_tag{
	Operand					place;
	Operand					passMode;
} parNode;

typedef struct callNode_tag {
	SymbolEntry *	func;
	SymbolEntry *	arg;
	Queue			params;
} callNode;


#ifdef DEBUG
void printParQuads(callNode * n){
	Queue params = n->params;
	printf("par quads of %s: ",n->func->id);
	if(isEmpty(params)) {printf("<empty>\n"); return;}
	genNode * p = params->first;
	while(p!=NULL) {
		parNode * pn = p->data; 
		printf("(%s,%s), ",pn->place->name,pn->passMode->name);
		fflush(stdout);
		p=p->next;
	}
	printf("\n");
}
#endif

/* -------------------------------------------------------------
   ---------------------- Global Variables ---------------------
   ------------------------------------------------------------- */

struct Memory mem;

Stack callStack;
Stack ifStack;
Stack forStack;

bool firstBlock = true;
bool OFLAG		= false;


/* -------------------------------------------------------------
   ----------------- Library Function Declaration --------------
   ------------------------------------------------------------- */

/* For #definitions for library function declaration module parameters look at general.h */

/* struct to represent a pramater of a library function */
typedef struct LibFuncParam_tag {
	char *		name;
	Type		type;
	PassMode	passMode;
} LibFuncParam;

/* struct to a library function */
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
	closeScope();
}


void declareAllLibFunc()
{
	// here we declare all the run-time library functions, first the internal (canot be called explicitly by tony programmer) and then the callable
	LibFunc libraryFunctions [LF_NUM] = {
		
		/* Internal */
		/* name		returnType			argNum	  for each arg: name, type, passMode		 */
		{ "newarrp",typeIArray(typeAny),	1, { {"size", typeInteger,			PASS_BY_VALUE}, } },
		{ "newarrv",typeIArray(typeAny),	1, { {"size", typeInteger,			PASS_BY_VALUE}, } },
		{ "consp",	typeList(typeAny),		2, { {"head", typeInteger,			PASS_BY_VALUE}, 
												 {"tail", typePointer(typeAny),	PASS_BY_VALUE}, } },
		{ "consv",	typeList(typeAny),		2, { {"head", typeInteger,			PASS_BY_VALUE}, 
												 {"tail", typePointer(typeAny),	PASS_BY_VALUE}, } },
		{ "head",	typeAny,				1, { {"l",	  typeList(typeAny),	PASS_BY_VALUE}, } },
		{ "tail",	typeList(typeAny),		1, { {"l",	  typeList(typeAny),	PASS_BY_VALUE}, } },

		/* Callable */
		/* name		returnType	argNum	  for each arg: name, type, passMode		 */
		{ "puti",	typeVoid,		1, { {"n", typeInteger,				PASS_BY_VALUE},	} },
		{ "putb",	typeVoid,		1, { {"b", typeBoolean,				PASS_BY_VALUE},	} },
		{ "putc",	typeVoid,		1, { {"c", typeChar,				PASS_BY_VALUE},	} },
		{ "puts",	typeVoid,		1, { {"s", typeIArray(typeChar),	PASS_BY_VALUE},	} },
		{ "geti",	typeInteger,	0, NULL												  },
		{ "getb",	typeBoolean,	0, NULL												  },
		{ "getc",	typeChar,		0, NULL												  },
		{ "gets",	typeVoid,		2, { {"n", typeInteger,				PASS_BY_VALUE}, 
										 {"s", typeIArray(typeChar),	PASS_BY_VALUE},	} },
		{ "abs",	typeInteger,	1, { {"n", typeInteger,				PASS_BY_VALUE},	} },
		{ "ord",	typeInteger,	1, { {"c", typeChar,				PASS_BY_VALUE},	} },
		{ "chr",	typeChar,		1, { {"n", typeInteger,				PASS_BY_VALUE},	} },
		{ "strlen",	typeInteger,	1, { {"s", typeIArray(typeChar),	PASS_BY_VALUE},	} },
		{ "strcmp",	typeInteger,	2, { {"s1",typeIArray(typeChar),	PASS_BY_VALUE},  
										 {"s2",typeIArray(typeChar),	PASS_BY_VALUE},	} },
		{ "strcpy",	typeVoid,		2, { {"trg",typeIArray(typeChar),	PASS_BY_VALUE}, 
										 {"src",typeIArray(typeChar),	PASS_BY_VALUE},	} },
		{ "strcat",	typeVoid,		2, { {"trg",typeIArray(typeChar),	PASS_BY_VALUE}, 
										 {"src",typeIArray(typeChar),	PASS_BY_VALUE},	} },
	};

	int i;
	for(i=0;i<LF_NUM;i++)
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
%token<val>	T_int_const	
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

program		: {openScope(); declareAllLibFunc();} func_def { if(OFLAG) {optimize();} printQuads(); printFinal(); skeletonEnd(); closeScope();}

/* -------------------------------------------------------------------------------------------------------------------------------- 
 *	BLOCK DEFINITION (FUNCTIONS)
 * -------------------------------------------------------------------------------------------------------------------------------- */ 

func_def	: "def"	{mem.forward=0;} header ':'	{if(firstBlock) {skeletonBegin($3); firstBlock=!firstBlock;}} /* first func_def, main block */ 
			  def_list							{genquad(O_UNIT,oU($3),o_,o_); }
			  stmt_list 
			  "end"								{backpatch($8.NEXT,quadNext); 
												 //printf("before endu\n");
												 genquad(O_ENDU,oU($3),o_,o_);
												 if(OFLAG) optimize();
												 printQuads(); 
												 printFinal();
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
					newParameter($1,mem.type,mem.ref,mem.func);
					} 
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
								 genquad(O_RET,o_,o_,o_);
								 $$.NEXT=emptylist();}
								/* check that this return stmt is in a block (function) with a return type t same as the expr.type */ 
			| "return" expr		{if(!equalType(currentScope->returnType,$2.type)) sserror("return statement is of different type than epxected");
								 if($2.cond) $2.place = evaluateCondition($2.TRUE,$2.FALSE);
								 genquad(O_ASSIGN,$2.place,o_,oRESULT);
								 genquad(O_RET,o_,o_,o_);
								 $$.NEXT=emptylist();}
			| if_clause			{$$.NEXT=$1.NEXT;} 
			| for_clause		{$$.NEXT=$1.NEXT;}
			;		


for_clause	: "for" simple_list ';' {push(forStack);				forNode * n=top(forStack);		n->condLabel=quadNext;}
				expr ';'			{if(!equalType($5.type,typeBoolean)) sserror("second part of 'for' clause must be a boolean expression");
									 if(!$5.cond) {ListPair l = createCondition($5.place); $5.TRUE=l.TRUE; $5.FALSE=l.FALSE;}
									 forNode *n=top(forStack);		n->loopLabel = quadNext;}	
				simple_list ':'		{forNode *n=top(forStack);		genquad(O_JUMP,o_,o_,oL(n->condLabel));	backpatch($5.TRUE,quadNext);}
				stmt_list			{forNode *n=top(forStack);		backpatch($11.NEXT,n->loopLabel);		genquad(O_JUMP,o_,o_,oL(n->loopLabel));}
				"end"				{pop(forStack);					$$.NEXT=$5.FALSE;} 



/* ----- IF ---- */

			/* the following form of grammar allows the desired precedence behaviour from if-clauses */
if_clause	: "if" expr			{if(!equalType($2.type,typeBoolean)) sserror("condition of 'if' clause must be a boolean expression");
								 if(!$2.cond) {ListPair l = createCondition($2.place); $2.TRUE=l.TRUE; $2.FALSE=l.FALSE;}
								 push(ifStack);						ifNode *n = top(ifStack);	
								 backpatch($2.TRUE,quadNext);		n->lastFalse=$2.FALSE;		
								} 
				':' stmt_list	{ifNode *n = top(ifStack);			n->endif=makelist(quadNext);	
								 genquad(O_JUMP,o_,o_,oSTAR);		n->endif=merge(n->endif,$5.NEXT);}
				elsif_clause 
				else_clause 
				"end"			{ifNode *n = top(ifStack);			$$.NEXT=merge(n->endif,n->lastFalse);	pop(ifStack);}
			;

elsif_clause: "elsif"			{ifNode *n = top(ifStack);			backpatch(n->lastFalse,quadNext);}
				expr			{if(!equalType($3.type,typeBoolean)) sserror("condition of 'if' clause must be a boolean expression");
								 if(!$3.cond) {ListPair l = createCondition($3.place); $3.TRUE=l.TRUE; $3.FALSE=l.FALSE;}
								 ifNode *n = top(ifStack);			backpatch($3.TRUE,quadNext);			n->lastFalse=$3.FALSE;
								}
				':' stmt_list	{ifNode *n = top(ifStack);			n->endif=merge(n->endif,makelist(quadNext));	
								 genquad(O_JUMP,o_,o_,oSTAR);		n->endif=merge(n->endif,$6.NEXT);}
				elsif_clause 
			| /* nothing */;

else_clause	: "else" ':'		{ifNode *n = top(ifStack);			backpatch(n->lastFalse,quadNext);			n->lastFalse=emptylist();}
				stmt_list		{ifNode *n = top(ifStack);			n->endif=merge(n->endif,makelist(quadNext));	
								 genquad(O_JUMP,o_,o_,oSTAR);		n->endif=merge(n->endif,$4.NEXT);}
			| /* nothing */

/* ------------- */


/* all simple commands have NEXT=emptylist() so w do not bother assigning NEXT attribute to simple or simple lists*/

simple		: "skip"			
								 /* atom is l-value && expr.type=atom.type */
			| atom ":=" expr	{if(!$1.lval) sserror("expression in the left of asssigment is not an lvalue as it should be");
								 if(!equalType($1.type,$3.type))	
									 sserror("type mismatch in assigment: left expr is %s while right is %s",typeToStr($1.type),typeToStr($3.type));
								 if($3.cond) $3.place = evaluateCondition($3.TRUE,$3.FALSE);
								 genquad(O_ASSIGN,$3.place,o_,$1.place);
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
								 if(!isCallableFunc(s)) ssmerror("function is not callable"); //we assume that there are some non callable functions
								 push(callStack);
								 callNode * n = top(callStack);
								 n->func = s;	
								 n->arg= s->u.eFunction.firstArgument;
								 n->params = newQueue(sizeof(parNode));
								}	
				expr_list ')'	{callNode * n = top(callStack);
								 SymbolEntry *s = n->func;
								 //generate par quads
								 Queue params = n->params;
								 while(!isEmpty(params)){
									parNode * p = removeFirst(params);
									genquad(O_PAR,p->place,p->passMode,o_);
								 }
								 if(!equalType(s->u.eFunction.resultType,typeVoid)){
									 SymbolEntry * w = newTemporary(s->u.eFunction.resultType);
									 genquad(O_PAR,oS(w),oRET,o_);
									 $$.place= oS(w);
								 }
								 else $$.place=NULL;
								 genquad(O_CALL,o_,o_,oU(s->id)); 
								 $$.type=s->u.eFunction.resultType;
								 pop(callStack);
								}
			| T_id '(' ')'		{SymbolEntry *s = lookupEntry($1,LOOKUP_ALL_SCOPES,true); 
								 if(s->entryType!=ENTRY_FUNCTION)		sserror("identifier is not a function");
								 if(s->u.eFunction.firstArgument!=NULL) sserror("function %s expects more arguments",s->id);
								 if(!equalType(s->u.eFunction.resultType,typeVoid)){
									 SymbolEntry * w = newTemporary(s->u.eFunction.resultType);
									 genquad(O_PAR,oS(w),oRET,o_);
									 $$.place= oS(w);
									 }
								 else $$.place=NULL;
								 genquad(O_CALL,o_,o_,oU(s->id)); 
								 $$.type=s->u.eFunction.resultType;
								}	
			

expr_list	: expr				{callNode * n = top(callStack);
								 SymbolEntry * arg = n->arg;
								 if(arg==NULL)								
									ssmerror("function %s expects less arguments",n->func->id);
								 if(!equalType($1.type,arg->u.eParameter.type))	
									ssmerror("type mismatch in function arguments: expected %s but found %s\n",
											 typeToStr(arg->u.eParameter.type),typeToStr($1.type));
								 if($1.cond) $1.place = evaluateCondition($1.TRUE,$1.FALSE);
								 if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $1.lval==false)
									ssmerror("parameter pass is by reference but argument is not an l-value");
								 else if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $1.lval==true){
									addLast(n->params);
									parNode * p = getLast(n->params);
									p->place = $1.place;
									p->passMode = oR;
								 }
							 	 else if (arg->u.eParameter.mode==PASS_BY_VALUE){
									addLast(n->params);
									parNode * p = getLast(n->params);
									p->place = $1.place;
									p->passMode = oV;
								 }
								 else internal("unmatched parameter case");
								 #ifdef DEBUG
								 printParQuads(n);
								 #endif
								 n->arg = arg->u.eParameter.next;
								}
				expr_full
			

expr_full	:',' expr			{callNode * n = top(callStack);
								 SymbolEntry * arg = n->arg;
								 if(arg==NULL)								
									ssmerror("function %s expects less arguments",n->func->id);
								 if(!equalType($2.type,arg->u.eParameter.type))	
									ssmerror("type mismatch in function arguments: expected %s but found %s\n",
											 typeToStr(arg->u.eParameter.type),typeToStr($2.type));
								 if($2.cond) $2.place = evaluateCondition($2.TRUE,$2.FALSE);
								 if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $2.lval==false)			
									ssmerror("parameter pass is by reference but argument is not an l-value");
								 else if(arg->u.eParameter.mode==PASS_BY_REFERENCE && $2.lval==true){
									addLast(n->params);
									parNode * p = getLast(n->params);
									p->place = $2.place;
									p->passMode = oR;
								 }
							 	 else if (arg->u.eParameter.mode==PASS_BY_VALUE){
									addLast(n->params);
									parNode * p = getLast(n->params);
									p->place = $2.place;
									p->passMode = oV;
								 }
								 else internal("unmatched parameter case");
								 #ifdef DEBUG
								 printParQuads(n);
								 #endif
								 n->arg = arg->u.eParameter.next;
								}
				expr_full		
			| /* nothing */		{callNode *n = top(callStack);	if(n->arg!=NULL) sserror("function %s expects more arguments",n->func);}



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
								 /* Attention: 
								  * Although we consider for strings: l-value to be true, strings cannot be in the left part of an assigment
								  * We consider them to be lval, so that if they are used as function arguments, they will be ALLOWED to pass 
								  * by reference. In assigment we perform an extra check to exclude strings from being assigned */
								}
			| call				{$$.type=$1.type;
								 $$.place=$$.place;
								 $$.lval=false;
								}
			| atom '[' expr ']' {if(!equalType($1.type,typeIArray(typeAny))) sserror("excessive brackets");
								 if(!equalType($3.type,typeInteger)) sserror("expression in brackets must be integer");
								 $$.type=($1.type)->refType;
								 SymbolEntry * w = newTemporary(typeIArray($$.type));
								 genquad(O_ARRAY,$1.place,$3.place,oS(w));
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
			
rval:		  T_int_const		{$$.type=typeInteger;	$$.place = oS( newConstant(NULL,typeInteger,$1) );	}
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
								 genquad(O_SUB,oS(newConstant("0",typeInteger,0)),$2.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '+' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator work only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad(O_ADD,$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '-' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad(O_SUB,$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '*' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad(O_MULT,$1.place,$3.place,oS(w));
								 $$.place=oS(w);
								 $$.cond=false;
								}	
			| expr '/' expr		{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad(O_DIV,$1.place,$3.place,oS(w));
								 $$.place=oS(w); 
								 $$.cond=false;
								}	
			| expr "mod" expr	{if(!equalType($1.type,typeInteger) || !equalType($3.type,typeInteger)) sserror("operator works only on int operands");
								 $$.type=typeInteger; 
								 SymbolEntry * w = newTemporary(typeInteger);
								 genquad(O_MOD,$1.place,$3.place,oS(w));
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
								 genquad(O_EQ,$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad(O_JUMP,o_,o_,oSTAR);
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
								 genquad(O_NE,$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad(O_JUMP,o_,o_,oSTAR);
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
								 genquad(O_LT,$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad(O_JUMP,o_,o_,oSTAR);
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
								 genquad(O_GT,$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad(O_JUMP,o_,o_,oSTAR);
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
								 genquad(O_LE,$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad(O_JUMP,o_,o_,oSTAR);
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
								 genquad(O_GE,$1.place,$3.place,oSTAR);
								 $$.FALSE=makelist(quadNext);
								 genquad(O_JUMP,o_,o_,oSTAR);
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
										 Operand w = oS(newTemporary(typeInteger));						//size of array in bytes
										 Operand z = oS(newTemporary($$.type));							//place for result of newarrv
										 // if type is array of any or list of any then use newarrp
										 if(equalType($2,typeIArray(typeAny)) || equalType($2,typeList(typeAny))){
											Operand s = oS(newConstant(NULL,typeInteger,sizeOfType($2)/2));	//size of referenced type in words FIXME
											genquad(O_MULT,$4.place,s,w);
											genquad(O_PAR,w,oV,o_);
											genquad(O_PAR,z,oRET,o_);
											genquad(O_CALL,o_,o_,oU("newarrp"));
										 } else {
											Operand s = oS(newConstant(NULL,typeInteger,sizeOfType($2)));	//size of referenced type in bytes
											genquad(O_MULT,$4.place,s,w);
											genquad(O_PAR,w,oV,o_);
											genquad(O_PAR,z,oRET,o_);
											genquad(O_CALL,o_,o_,oU("newarrv"));
										 }
										 $$.place=z;
										 $$.cond=false;
										}


			| expr '#' expr				{if(equalType($3.type,typeList(typeAny)) && equalType($1.type,$3.type->refType)) 
											$$.type=typeList($1.type); 
										 else sserror("type mismatch in list construction (head: %s tail: %s)",typeToStr($1.type),typeToStr($1.type));
										 if($1.cond) $1.place = evaluateCondition($1.TRUE,$1.FALSE);
										 Operand z = oS(newTemporary($$.type));
										 if(equalType($1.type,typeIArray(typeAny)) || equalType($1.type,typeList(typeAny))){
											 genquad(O_PAR,$1.place,oV,o_);
											 genquad(O_PAR,$3.place,oV,o_);
											 genquad(O_PAR,z,oRET,o_);
											 genquad(O_CALL,o_,o_,oU("consp"));
										 } else {
											 genquad(O_PAR,$1.place,oV,o_);
											 genquad(O_PAR,$3.place,oV,o_);
											 genquad(O_PAR,z,oRET,o_);
											 genquad(O_CALL,o_,o_,oU("consv"));
										 }
										 $$.place=z;
										 $$.cond=false;
										}

			| "nil"						{$$.type=typeList(typeAny);		$$.place=oS(newConstant("nil",$$.type));	$$.cond=false;}

			| "nil?" '(' expr ')'		{if(!equalType($3.type,typeList(typeAny))) sserror("expression in brackets must be some list type");
										 //printf("in nil?\n");
										 $$.type=typeBoolean;
										 $$.TRUE=makelist(quadNext);
										 genquad(O_EQ,$3.place,oS(newConstant("nil",typeList(typeAny))),oSTAR);
										 $$.FALSE=makelist(quadNext);
										 genquad(O_JUMP,o_,o_,oSTAR);
										 $$.cond=true;
										 //printf("out of nil?\n");
										 }

			| "head" '(' expr ')'		{if(!equalType($3.type,typeList(typeAny))) 
											sserror("expression in brackets must be some list type but is %s",typeToStr($3.type));
										 $$.type=$3.type->refType;
										 Operand z = oS(newTemporary($$.type));
										 genquad(O_PAR,$3.place,oV,o_);
										 genquad(O_PAR,z,oRET,o_);
										 genquad(O_CALL,o_,o_,oU("head"));
										 $$.place=z;
										 $$.cond=false;
										}

			| "tail" '(' expr ')'		{if(!equalType($3.type,typeList(typeAny))) sserror("expression in brackets must be some list type");
										 $$.type=$3.type;
										 Operand z = oS(newTemporary($$.type));
										 genquad(O_PAR,$3.place,oV,o_);
										 genquad(O_PAR,z,oRET,o_);
										 genquad(O_CALL,o_,o_,oU("tail"));
										 $$.place=z;
										 $$.cond=false;
										}
			


/* function call limitations 
 * 1. T_id name of the function exists in current scope
 * 2. types of arguments passed are of the same type
 * 3. if arguments are passed by reference, they must be valid l-values
 * /

/* In each T_id allocation we must check if the specific T_id is uniqe = 1st time to be created. ONLY in T_id ALLOCAATION */


/* =================================================================================================================================== */
/* =================================================================================================================================== */

%%

/* Global filestream pointers */

extern FILE *	yyin;
extern FILE *	iout;
#ifdef INTERMEDIATE
FILE *	fout;
#else
extern FILE * fout;
#endif

const char *	filename;


/* removeExtension():
 * Returns the char * s, without the part from the last dot to the end 
 * Called by parseArguments() 
 */
void removeExtension(char * s)
{
	int i=0;
	while(s[i]!='\0') i++;
	i--;
	while(i>=0){
		if(s[i]=='.')		{s[i]='\0';	break;}		//we found the last dot
		else if(s[i]=='/')	break;					//in Linux we left the directory so the name is clean of extensions
		else				i--;					//keep searching for the dot of the extension
	}
}


void parseArguments(int argc,char * argv[]){

	bool FFLAG = false; 
	bool IFLAG = false;

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

	
	#define FILE_EXTENSION_LENGTH 5 // max{".asm",".imm"}+1
	unsigned int size = strlen(filename) + FILE_EXTENSION_LENGTH; 
	#undef FILE_EXTENSION_LENGTH
	char fclean[size], buf[size];
	strcpy(fclean,filename);
	removeExtension(fclean);

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


#ifdef LINUX_SYS
void sigsegv_hndler(int signum)
{
	error("SIGSEV (Segmentation fault) caught. Printing and exiting...");
	if(iout!=NULL) {printQuads();	fflush(iout);	fclose(iout);}
	if(fout!=NULL) {printFinal();	fflush(fout);	fclose(fout);}
	fatal("SIGSEV: exited");
}
#endif

int main(int argc, char * argv[])
{
	/* Initialize variables */
	callStack = newStack(sizeof(callNode));
	forStack  = newStack(sizeof(forNode));
	ifStack   = newStack(sizeof(ifNode));

	#ifdef LINUX_SYS
	/* Install Singal Handler */
	signal(SIGSEGV, sigsegv_hndler);
	#endif

	/* Arguments parsing */
	parseArguments(argc,argv);

	/* Initializing Symbol Table  */
	initSymbolTable(SYMBOLTABLE_SIZE);

	/* Calling the syntax parser */
	return yyparse();

}
