/******************************************************************************
 *  CVS version:
 *     $Id: general.h,v 1.1 2004/05/05 22:00:08 nickie Exp $
 ******************************************************************************
 *
 *  C header file : general.h
 *  Project       : PCL Compiler
 *  Version       : 1.0 alpha
 *  Written by    : Nikolaos S. Papaspyrou (nickie@softlab.ntua.gr)
 *  Date          : May 5, 2004
 *  Description   : Generic symbol table in C, general header file
 *
 *  Comments: (in Greek iso-8859-7)
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */

#include <stdio.h>

#ifndef __GENERAL_H__
#define __GENERAL_H__


/* ---------------------------------------------------------------------
 * ----------- Πρωτότυπα των συναρτήσεων διαχείρισης μνήμης ------------
 * --------------------------------------------------------------------- */

void * new    (size_t);
void   delete (void *);


/* ---------------------------------------------------------------------
   -------------- Καθολικές μεταβλητές του μεταγλωττιστή ---------------
   --------------------------------------------------------------------- */

extern int linecount;
extern const char * filename;


/* ---------------------------------------------------------------------
   ---------------------- General Definitions Guide --------------------
   --------------------------------------------------------------------- */

/* ommit definition if compiler is NOT meant to run on a Linux system */
#define LINUX_SYS

/* Library functions definitions */
#define LF_PARAM_NUM_MAX 2
#define LF_INTERNAL_NUM 6
#define LF_CALLABLE_NUM 15
#define LF_NUM (LF_INTERNAL_NUM + LF_CALLABLE_NUM)


/* Other definitions of global interest declared in local files:
 * - QUAD_ARRAY_SIZE		max number of quads in a function + 1			intermediate.h
 * - STRINGS_MAX			max number of string literals in a program		final.c
 * - STRING_LABEL_BUF_SIZE	bytes for a string label, limits strings liter	final.c
 * - LABEL_BUF_SIZE			bytes for a label, limits quads and functions	final.c
 * - SYMBOL_TABLE_SIZE		number of buckets of the hash Symbol Table		parser.c
 */

/* Definitions/Flags imposed by Makefile:
 * - INTERMEDIATE:	for intermediate code production only, not final assembly code
 * - DEBUG:			for printing various progress messages
 */

#endif
