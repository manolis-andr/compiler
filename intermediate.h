/******************************************************************************
 *
 *  C header file : intermediate.h
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

#include "symbol.h"

#ifndef __INTERMEDIATE_H__
#define __INTERMEDIATE_H__


/* ---------------------------------------------------------------------
   --------------------------- Ορισμός τύπων ---------------------------
   --------------------------------------------------------------------- */

typedef enum{
	OPERAND_SYMBOL,
	OPERAND_QLABEL,
	OPERAND_UNIT,
	OPERAND_DEREFERENCE,
	OPERAND_ADDRESS,
	OPERAND_PASSMODE,
	OPERAND_NULL,
	OPERAND_STAR,
}OperandType;


typedef struct Operand_tag * Operand;

struct Operand_tag{
	OperandType		type;
	const char *	name;

	union{
		SymbolEntry *	symbol;
		int				quadLabel;	
	}u;

};


typedef struct Quad_tag{
	const char *	op;
	Operand			x;
	Operand			y;
	Operand			z;
} Quad;


/* ----------------------- List ------------------------------ */

typedef struct Node_tag{
	int data;
	struct Node_tag * next;
} Node;

typedef struct{
	Node * head;
}List;

typedef struct ListPair_tag{
	List * TRUE;
	List * FALSE;
} ListPair;


/* ---------------------------------------------------------------------
   ------------------ Ορισμός καθολικών μεταβλητών ---------------------
   --------------------------------------------------------------------- */

extern Quad			q[];
extern int			qprintStart;

extern const Operand oR  ; 
extern const Operand oV  ;
extern const Operand oRET;
extern const Operand o_  ;
extern const Operand oSTAR;

/* ---------------------------------------------------------------------
   --------------- Πρωτότυπα των βοηθητικών συναρτήσεων ----------------
   --------------------------------------------------------------------- */

void	genquad		(const char * op,Operand x,Operand y,Operand z);
List*	emptylist	(void);
List*	makelist	(int qnum);
List*	merge		(List * l1,List * l2);
void	backpatch	(List * l,int qnum);

Operand	oS			(SymbolEntry *);		/* creates symbol operand */
Operand	oL			(int quadLabel);		/* creates quad label operand */
Operand oU			(const char *unitName); /* creates unit operand */
Operand oD			(SymbolEntry *);		/* creates dereference [x] operand */ 	
Operand oA			(SymbolEntry *);		/* creates address {x} operand */ 		

void	printList	(List * l);
void	printQuads	(void);

ListPair	createCondition		(Operand place);
Operand		evaluateCondition	(List * TRUE, List * FALSE);

void	test();

#endif
