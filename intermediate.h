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
	O_ASSIGN,
	O_ARRAY,
	O_ADD,
	O_SUB,
	O_MULT,
	O_DIV,
	O_MOD,
	O_EQ,   // =
	O_NE,   // <>
	O_LT,	// <
	O_GT,	// >
	O_LE,	// <=
	O_GE,	// >=
	O_IFB,
	O_JUMP,
	O_UNIT,
	O_ENDU,
	O_CALL,
	O_RET,
	O_PAR
}OperatorType;


typedef enum{
	OPERAND_SYMBOL,
	OPERAND_QLABEL,
	OPERAND_UNIT,
	OPERAND_DEREFERENCE,
	OPERAND_ADDRESS,
	OPERAND_PASSMODE,
	OPERAND_NULL,
	OPERAND_STAR,
	OPERAND_RESULT,
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
	int				num;	//the number of the quad, if it is negative the quad has been omited by the optimizer
	OperatorType	op;
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

extern FILE *		iout;

extern Quad			q[];
extern int			qprintStart;

extern const Operand oR  ; 
extern const Operand oV  ;
extern const Operand oRET;
extern const Operand o_  ;
extern const Operand oSTAR;
extern const Operand oRESULT;

/* ---------------------------------------------------------------------
   --------------- Πρωτότυπα των βοηθητικών συναρτήσεων ----------------
   --------------------------------------------------------------------- */

void	printQuads	(void);
void	optimize	(void);

void	genquad		(OperatorType op,Operand x,Operand y,Operand z);

List*	emptylist	(void);
List*	makelist	(int qnum);
List*	merge		(List * l1,List * l2);
void	backpatch	(List * l,int qnum);

Operand	oS			(SymbolEntry *);		/* creates symbol operand */
Operand	oL			(int quadLabel);		/* creates quad label operand */
Operand oU			(const char *unitName); /* creates unit operand */
Operand oD			(SymbolEntry *);		/* creates dereference [x] operand */ 	
Operand oA			(SymbolEntry *);		/* creates address {x} operand */ 		

ListPair	createCondition		(Operand place);
Operand		evaluateCondition	(List * TRUE, List * FALSE);

SymbolEntry *	getSymbol		(Operand o);
const char *	otos			(OperatorType op);	/* returns the string representation of an OperatorType
													 * caled in printing (pritQuads and printFinal) */

#ifdef DEBUG
void	printList	(List * l);
#endif

#endif
