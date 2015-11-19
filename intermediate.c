/******************************************************************************
 
 *  C header file : intermediate.c
 *  Project       : Tony Compiler
 *  Version       : 1.0 alpha
 *  Written by    : Manolis	Androulidakis
 *  Date          : September 21, 2014
 *  Description   : Structures and helper routines for intermediate code
 *
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "intermediate.h"
#include "general.h"
#include "symbol.h"
#include "error.h"


/* -------------------------------------------------------------
   ---------------------- Global variables ---------------------
   ------------------------------------------------------------- */

FILE * iout = NULL;

// circular buffer for quads. Period = QUAD_ARRAY_SIZE
//max number of quads supported in a function = QUAD_ARRAY_SIZE-1.
Quad q[QUAD_ARRAY_SIZE];

int  qprintStart = 1;

static struct Operand_tag operandConst [] = {
	    { OPERAND_PASSMODE,	"V",	NULL },
		{ OPERAND_PASSMODE,	"R",	NULL },
		{ OPERAND_PASSMODE,	"RET",	NULL },
		{ OPERAND_NULL,		"-",	NULL },	
		{ OPERAND_STAR,		"*",	NULL },
		{ OPERAND_RESULT,	"$$",	NULL }
};

const Operand oV    = &(operandConst[0]);
const Operand oR	= &(operandConst[1]);
const Operand oRET	= &(operandConst[2]);
const Operand o_	= &(operandConst[3]);
const Operand oSTAR	= &(operandConst[4]);
const Operand oRESULT =	&(operandConst[5]);


/* -------------------------------------------------------------
   ------------------------- Functions -------------------------
   ------------------------------------------------------------- */

void genquad(OperatorType op,Operand x,Operand y,Operand z)
{
	q[quadNext].num= quadNext;
	q[quadNext].op = op;
	q[quadNext].x  = x;
	q[quadNext].y  = y;
	q[quadNext].z  = z;
	quadNext++;
	if(quadNext==QUAD_ARRAY_SIZE) internal("Maximum quad limit reached. Recompile with a greater QUAD_ARRAY_SIZE\n");
}


void printQuads()
{
	int i;
	for(i=qprintStart;i<quadNext;i++){
		if(ISACTIVE(q[i].num)) 
			fprintf(iout,"%d: %s, %s, %s, %s\n",q[i].num,otos(q[i].op),q[i].x->name,q[i].y->name,q[i].z->name);
	}
	qprintStart=quadNext;
}


Operand oS(SymbolEntry * s)
{
	Operand o = (Operand ) new(sizeof(struct Operand_tag));
	o->type	= OPERAND_SYMBOL;
	o->name = s->id;
	o->u.symbol	= s;
	return o;
}

Operand oL(int quadLabel)
{
	Operand o = (Operand ) new(sizeof(struct Operand_tag));
	o->type	= OPERAND_QLABEL;
	char buf[12];		//12 = max letter of int
	snprintf(buf,12,"%d",quadLabel);
	o->name = strdup(buf);
	o->u.quadLabel = quadLabel;
	return o;
}

//called both on definition and on call of a function (block)
Operand oU(const char * unitName)
{
	#ifdef DEBUG
	//printf("oU: %s\n",unitName);
	#endif
	SymbolEntry * s = lookupEntry(unitName,LOOKUP_ALL_SCOPES,false);
	if(s==NULL) internal("oU: function not declared in SymbolTable");
	Operand o = (Operand ) new(sizeof(struct Operand_tag));
	o->type = OPERAND_UNIT;
	o->name = s->id;
	o->u.symbol = s;
	#ifdef DEBUG
	//printf("oU: %s finished\n",unitName);
	#endif
	return o;
}

Operand oD(SymbolEntry * s)
{
	Operand o = (Operand ) new(sizeof(struct Operand_tag));
	o->type = OPERAND_DEREFERENCE;
	int buf_size = 3+strlen(s->id);
	char buf[buf_size];
	snprintf(buf,buf_size,"[%s]",s->id);
	o->name = strdup(buf);
	o->u.symbol = s;
	return o;
}

Operand oA(SymbolEntry * s)
{
	Operand o = (Operand ) new(sizeof(struct Operand_tag));
	o->type = OPERAND_ADDRESS;
	int buf_size = 3+strlen(s->id);
	char buf[buf_size];
	snprintf(buf,buf_size,"{%s}",s->id);
	o->name = strdup(buf);
	o->u.symbol = s;
	return o;
}


ListPair createCondition(Operand place)
{	
	#ifdef DEBUG
	printf("got in createCondition!\n");
	#endif
	ListPair l;
	l.TRUE = makelist(quadNext);
	genquad(O_IFB,place,o_,oSTAR);
	l.FALSE = makelist(quadNext);
	genquad(O_JUMP,o_,o_,oSTAR);
	#ifdef DEBUG
	printf("got out of createCondition!\n");
	#endif
	return l;
}

Operand evaluateCondition(List * TRUE, List * FALSE)
{
	#ifdef DEBUG
	printf("got in evaluateCondition!\n");
	#endif
	SymbolEntry * w = newTemporary(typeBoolean);
	backpatch(TRUE,quadNext);
	genquad(O_ASSIGN,oS(newConstant("true",typeBoolean,true)),o_,oS(w));
	genquad(O_JUMP,o_,o_,oL(quadNext+2));
	backpatch(FALSE,quadNext);
	genquad(O_ASSIGN,oS(newConstant("false",typeBoolean,false)),o_,oS(w));
	#ifdef DEBUG
	printf("got out of evaluateCondition!\n");
	#endif
	return oS(w);
}

/* -------------------------------------------------------------
   ----------------------- Optimizations -----------------------
   ------------------------------------------------------------- */

/* Optimizations 
	1. inverse copy propagation
 	2. constant propagation 
	3. algebraic transformations
	4. boolean transformations
	5. remove jumps to next instr
*/

void opt_inverseCopyPropagation()
{
	int i;
	//up to quadNext-1 because the quads that will be transformed always go in pairs
	for(i=qprintStart;i<quadNext-1;i++){
		if(!ISACTIVE(q[i].num)) continue;
		OperatorType op1 = q[i].op;
		OperatorType op2 = q[i+1].op;
		if( (op1==O_ADD || op1==O_SUB || op1==O_MULT || op1==O_DIV || op1==O_MOD) && op2==O_ASSIGN ){
			if(getSymbol(q[i].z)==getSymbol(q[i+1].x)) {
				q[i].z = q[i+1].z;
				q[i+1].num = -1; //remove quad, deactivate
				#ifdef DEBUG
				printf("opt: inverseCopyPropagation: quad %d modified, quad %d removed\n",i,i+1);
				#endif
			}
		}
	}
}

void opt_constantFolding()
{
	int i;
	for(i=qprintStart;i<quadNext;i++){
		if(!ISACTIVE(q[i].num)) continue;
		OperatorType op = q[i].op;
		if( (op==O_ADD || op==O_SUB || op==O_MULT || op==O_DIV || op==O_MOD) && 
			(getSymbol(q[i].x)->entryType==ENTRY_CONSTANT && getSymbol(q[i].y)->entryType==ENTRY_CONSTANT))
		{
			int v1 = getSymbol(q[i].x)->u.eConstant.value.vInteger;
			int v2 = getSymbol(q[i].y)->u.eConstant.value.vInteger;
			int res;
			switch(op){
				case O_ADD: res=v1+v2; break;
				case O_SUB:	res=v1-v2; break;
				case O_MULT: res=v1*v2; break;
				case O_DIV: res=v1/v2; break;
				case O_MOD: res=v1%v2; break;
			}
			q[i].op = O_ASSIGN;
			q[i].x = oS(newConstant(NULL,typeInteger,res));
			q[i].y = o_;
		}
	}
}

void opt_algebraicTransformations()
{
	int i;
	SymbolEntry * s;
	for(i=qprintStart;i<quadNext;i++){
		if(!ISACTIVE(q[i].num)) continue;
		if(q[i].op==O_ADD){
			// 0 + x = x
			s = getSymbol(q[i].x);
			if(s->entryType==ENTRY_CONSTANT && s->u.eConstant.value.vInteger==0)
				{ q[i].op=O_ASSIGN;	q[i].x=q[i].y;	q[i].y=o_;	continue;	}
			// x + 0 = x
			s = getSymbol(q[i].y);
			if(s->entryType==ENTRY_CONSTANT && s->u.eConstant.value.vInteger==0)
				{ q[i].op=O_ASSIGN;	q[i].y=o_;					continue;	}
		}
		else if(q[i].op==O_MULT){
			// 0 * x = 0
			s = getSymbol(q[i].x);
			if(s->entryType==ENTRY_CONSTANT && s->u.eConstant.value.vInteger==0)
				{ q[i].op=O_ASSIGN;	q[i].y=o_;					continue;	}
			// 1 * x = x
			if(s->entryType==ENTRY_CONSTANT && s->u.eConstant.value.vInteger==1)
				{ q[i].op=O_ASSIGN;	q[i].x=q[i].y;	q[i].y=o_;	continue;	}
			s = getSymbol(q[i].y);
			// x * 0 = 0
			if(s->entryType==ENTRY_CONSTANT && s->u.eConstant.value.vInteger==0)
				{ q[i].op=O_ASSIGN;	q[i].x=q[i].y;	q[i].y=o_;	continue;	}
			// x * 1 = x
			if(s->entryType==ENTRY_CONSTANT && s->u.eConstant.value.vInteger==1)
				{ q[i].op=O_ASSIGN;	q[i].y=o_;					continue;	}
		}
	}
}

//ommits jumps to the following quad (flow will get there anyway)
void opt_oneStepJumps()
{	
	int i;
	for(i=qprintStart;i<quadNext;i++){
		if(!ISACTIVE(q[i].num)) continue;
		if(q[i].op==O_JUMP && q[i].z->u.quadLabel==i+1) 
			q[i].num = -1;
	}
}

void optimize()
{	
	opt_inverseCopyPropagation(); //first, if constantFolding first, it will not work
	opt_constantFolding();
	opt_algebraicTransformations();
	//opt_booleanTransformations();
	opt_oneStepJumps();
}


/* -------------------------------------------------------------
   ---------------------- List Functions ----------------------
   ------------------------------------------------------------- */

List* emptylist()
{
	List *l = (List *)new(sizeof(List));
	l->head = NULL;
	return l;
}

List* makelist(int qnum)
{
	List *l = (List *)new(sizeof(List));
	Node *n = (Node *)new(sizeof(Node));
	n->data = qnum;
	n->next = NULL;
	l->head = n;
	return l;
}

//crosses 2nd list, so put large list first
List* merge(List *l1, List *l2)
{
	if(l2->head==NULL) return l1;
	Node * p = l2->head;
	while(p->next!=NULL) p=p->next;
	p->next=l1->head;
	return l2;
}

void backpatch(List *l,int qnum)
{
	Operand dest = oL(qnum);
	Node * p = l->head;
	Node * t;
	while(p!=NULL){
		int index = p->data;
		Quad qd = q[index];
		if(qd.x==oSTAR) q[index].x = dest;	
		if(qd.y==oSTAR) q[index].y = dest;	
		if(qd.z==oSTAR) q[index].z = dest;	
		/* As we traverse we delete the elements of the list */
		t=p;
		p=p->next;
		delete(t);
	}
	l->head=NULL; //list has been emptied
}

#ifdef DEBUG
void printList(List *l){
	Node * p = l->head;
	if(p==NULL) printf("<empty>");
	while(p!=NULL){
		printf("%d ",p->data);
		p=p->next;
	}
	printf("\n");
}
#endif

/* -------------------------------------------------------------
   ------------------ Other Helper Functions -------------------
   ------------------------------------------------------------- */

SymbolEntry * getSymbol(Operand o){ 
	switch(o->type){
		case OPERAND_SYMBOL:
		case OPERAND_DEREFERENCE:
		case OPERAND_ADDRESS:
		case OPERAND_UNIT:
			return o->u.symbol;
		default:
			return NULL;
	}
}

//operator to string - alternatively we can allocate an const char * array with those values
const char * otos(OperatorType op)
{
	switch(op){
		case O_ASSIGN:	return ":=";
		case O_ARRAY:	return "array";
		case O_ADD:		return "+";
		case O_SUB:		return "-";
		case O_MULT:	return "*";
		case O_DIV:		return "/";
		case O_MOD:		return "mod";
		case O_EQ:		return "=";
		case O_NE:		return "<>";
		case O_LT:		return "<";
		case O_GT:		return ">";
		case O_LE:		return "<=";
		case O_GE:		return ">=";
		case O_IFB:		return "ifb";
		case O_JUMP:	return "jump";
		case O_UNIT:	return "unit";
		case O_ENDU:	return "endu";
		case O_CALL:	return "call";
		case O_RET:		return "ret";
		case O_PAR:		return "par";
		default:		return NULL;
	}
}

