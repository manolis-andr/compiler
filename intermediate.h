/******************************************************************************
 *
 *  C header file : intermediate.h
 *  Project       : Tony Compiler
 *  Version       : 1.0 alpha
 *  Written by    : Manolis	Androulidakis
 *  Date          : September 21, 2015
 *  Description   : Structures and helper routines for intermediate code
 *
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */


#ifndef __INTERMEDIATE_H__
#define __INTERMEDIATE_H__

#include "symbol.h"

/* initial num of quads supported in a tony programm: QUAD_ARRAY_SIZE - 1
 * if there is need for more we use realloc to gain more 
 */
#define QUAD_ARRAY_SIZE 256		

//checks if after optimization a quad remains present (active) and has not been deleted
#define ISACTIVE(NUM) ((NUM)<0 ? false : true)

/* ---------------------------------------------------------------------
   --------------------------- Ορισμός τύπων ---------------------------
   --------------------------------------------------------------------- */

typedef enum {
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
} OperatorType;


typedef enum {
	OPERAND_SYMBOL,
	OPERAND_QLABEL,
	OPERAND_UNIT,
	OPERAND_DEREFERENCE,
	OPERAND_ADDRESS,
	OPERAND_PASSMODE,
	OPERAND_NULL,
	OPERAND_STAR,
	OPERAND_RESULT,
} OperandType;


typedef struct Operand_tag * Operand;

struct Operand_tag{
	OperandType		type;
	const char *	name;

	union{
		SymbolEntry *	symbol;
		int				quadLabel;
	}u;

};


typedef struct Quad_tag {
	int				num;	//the number of the quad, if it is negative the quad has been omited by the optimizer
	OperatorType	op;
	Operand			x;
	Operand			y;
	Operand			z;
} Quad;


/* ----------------------- List ------------------------------ */

/* Lists of quad numbers, that contain a * (oSTAR) and will be backpatched */ 

typedef struct Node_tag {
	int data;
	struct Node_tag * next;
} Node;

typedef struct {
	Node * head;
} List;

typedef struct ListPair_tag {
	List * TRUE;
	List * FALSE;
} ListPair;


/* ---------------------------------------------------------------------
   ------------------ Ορισμός καθολικών μεταβλητών ---------------------
   --------------------------------------------------------------------- */

extern FILE *		iout;

extern Quad			*q;

extern const Operand oR  ; 
extern const Operand oV  ;
extern const Operand oRET;
extern const Operand o_  ;
extern const Operand oSTAR;
extern const Operand oRESULT;

/* ---------------------------------------------------------------------
   --------------- Πρωτότυπα των βοηθητικών συναρτήσεων ----------------
   --------------------------------------------------------------------- */

/* Interface to parser */

void	printQuads	(void);
void	optimize	(void);
void	initIntermediate (void);

void	genquad		(OperatorType op,Operand x,Operand y,Operand z);

List*	emptylist	(void);
List*	makelist	(int qnum);
List*	merge		(List * l1,List * l2);
void	backpatch	(List * l,int qnum);

Operand	oS			(SymbolEntry *);	/* creates symbol operand */
Operand	oL			(int quadLabel);	/* creates quad label operand */
Operand oU			(SymbolEntry *);	/* creates unit operand */
Operand oD			(SymbolEntry *);	/* creates dereference [x] operand */ 	
Operand oA			(SymbolEntry *);	/* creates address {x} operand */ 		

ListPair	createCondition		(Operand place);
Operand		evaluateCondition	(List * TRUE, List * FALSE);

/* Interface to final */

SymbolEntry *	getSymbol		(Operand o);
const char *	otostr			(OperatorType op);	/* returns the string representation of an OperatorType
													 * caled in printing (pritQuads and printFinal) */
#ifdef DEBUG
void	printList	(List * l);
#endif

#endif
