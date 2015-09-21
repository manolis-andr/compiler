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
	fprintf(stdout,"Quads: \n");
	for(i=0;i<quadNext;i++)
		fprintf(stdout,"%d:\t %s\t %s\t %s\t %s\t\n",i,q[i].op,q[i].x->name,q[i].y->name,q[i].z->name);
}

/*
void printOperand(Operand *o){
	switch(o->type){
		case OPERAND_SYMBOL:	printf("%s",(o->u.symbol)->id);
		case OPERAND_QLABEL:	printf("%d",o->u.quadLabel);
		case OPERAND_NULL:		printf("-");
		case OPERAND_STAR:		printf("*");
		case OPERAND_PASSMODE:
			switch(o->u.passMode){
				case PASS_BY_VALUE:		printf("V");
				case PASS_BY_REFERENCE:	printf("R");
				case PASS_RESULT:		printf("RET");
			}
	}
}*/


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

List* merge(List *l1, List *l2)
{
	if(l1->head==NULL) return l2;
	Node * p = l1->head;
	while(p->next!=NULL) p=p->next;
	p->next=l2->head;
	return l1;
}

void backpatch(List *l,Operand dest)
{
	if(dest->type!=OPERAND_QLABEL) internal("only give labels for backpatching");
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

genquad("+",o_,o_,oSTAR);
genquad("*",o_,oR,oSTAR);
genquad("array",o_,oRET,oSTAR);

printQuads();

List *l2 = makelist(0);
printList(l2);
List *l3 = merge(l2,makelist(2));
printList(l3);
backpatch(l3,oL(4));
printQuads();
printList(l3);


}
