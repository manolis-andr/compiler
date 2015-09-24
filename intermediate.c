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

#ifndef QUAD_ARRAY_SIZE
#define QUAD_ARRAY_SIZE 256
#endif

Quad q[QUAD_ARRAY_SIZE];

int  qprintStart = 1;

FILE * iout;
FILE * fout;

static struct Operand_tag operandConst [] = {
	    { OPERAND_PASSMODE,	"V",	NULL },
		{ OPERAND_PASSMODE,	"R",	NULL },
		{ OPERAND_PASSMODE,	"RET",	NULL },
		{ OPERAND_NULL,		"-",	NULL },	
		{ OPERAND_STAR,		"*",	NULL }
};

const Operand oV    = &(operandConst[0]);
const Operand oR	= &(operandConst[1]);
const Operand oRET	= &(operandConst[2]);
const Operand o_	= &(operandConst[3]);
const Operand oSTAR = &(operandConst[4]);


/* -------------------------------------------------------------
   ------------------------- Functions -------------------------
   ------------------------------------------------------------- */

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

Operand oU(const char * unitName)
{
	Operand o = (Operand ) new(sizeof(struct Operand_tag));
	o->type = OPERAND_UNIT;
	o->name = unitName;
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
}

void genquad(const char * op,Operand x,Operand y,Operand z)
{
	q[quadNext].op = op;
	q[quadNext].x  = x;
	q[quadNext].y  = y;
	q[quadNext].z  = z;
	quadNext++;
}


void printQuads()
{
	int i;
	for(i=qprintStart;i<quadNext;i++)
		fprintf(iout,"%d: %s, %s, %s, %s\n",i,q[i].op,q[i].x->name,q[i].y->name,q[i].z->name);
	qprintStart=quadNext;
}


/* -------------------------------------------------------------
   -------------------- Helper List Functions ------------------
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
		Quad qd = q[p->data];
		if(qd.x==oSTAR) q[p->data].x = dest;	
		if(qd.y==oSTAR) q[p->data].y = dest;	
		if(qd.z==oSTAR) q[p->data].z = dest;	
		/* As we traverse we delete the elements of the list */
		t=p;
		p=p->next;
		delete(t);
	}
	l->head=NULL; //list has been emptied
}

void printList(List *l){
	Node * p = l->head;
	if(p==NULL) printf("<empty>");
	while(p!=NULL){
		printf("%d ",p->data);
		p=p->next;
	}
	printf("\n");
}


void  test()
{

}
