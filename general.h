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

#define LF_PARAM_NUM_MAX 2
#define LF_INTERNAL_NUM 6
#define LF_CALLABLE_NUM 15
#define LF_NUM (LF_INTERNAL_NUM + LF_CALLABLE_NUM)



#endif
