/******************************************************************************
 *  CVS version:
 *     $Id: error.h,v 1.1 2003/05/13 22:21:01 nickie Exp $
 ******************************************************************************
 *
 *  C header file : error.h
 *  Project       : PCL Compiler
 *  Version       : 1.0 alpha
 *  Written by    : Nikolaos S. Papaspyrou (nickie@softlab.ntua.gr)
 *  Date          : May 14, 2003
 *  Description   : Generic symbol table in C, simple error handler
 *
 *  Comments: (in Greek iso-8859-7)
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */


#ifndef __ERROR_H__
#define __ERROR_H__

/* error numbers returning to OS after exit call, on success returns 0 */
#define SYNTAX_ERRNUM	1
#define SEMANTIC_ERRNUM	2
#define INTERNAL_ERRNUM	(-1)
#define FATAL_ERRNUM	(-2)

/* ---------------------------------------------------------------------
   --------- Πρωτότυπα των συναρτήσεων του χειριστή σφαλμάτων ----------
   --------------------------------------------------------------------- */

void internal (const char * fmt, ...);
void fatal    (const char * fmt, ...);
void error    (const char * fmt, ...);
void warning  (const char * fmt, ...);

void sserror  (const char * fmt, ...);
void ssmerror (const char * fmt, ...);


#endif
