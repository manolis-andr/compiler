/******************************************************************************
 *  CVS version:
 *     $Id: symbol.c,v 1.3 2004/05/05 22:00:08 nickie Exp $
 ******************************************************************************
 *
 *  C code file : symbol.c
 *  Project     : PCL Compiler
 *  Version     : 1.0 alpha
 *  Written by  : Nikolaos S. Papaspyrou (nickie@softlab.ntua.gr)
 *  Modified by : Manolis Androulidakis
 *  Date        : May 14, 2003
 *  Description : Generic symbol table in C
 *
 *  Comments: (in Greek iso-8859-7)
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */


/* ---------------------------------------------------------------------
   ---------------------------- Header files ---------------------------
   --------------------------------------------------------------------- */

#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>

#include "general.h"
#include "error.h"
#include "symbol.h"


/* ---------------------------------------------------------------------
   ------------- Καθολικές μεταβλητές του πίνακα συμβόλων --------------
   --------------------------------------------------------------------- */

Scope        * currentScope;           /* Τρέχουσα εμβέλεια              */
unsigned int   quadNext;               /* Αριθμός επόμενης τετράδας      */
unsigned int   tempNumber;             /* Αρίθμηση των temporaries       */

static unsigned int   hashTableSize;   /* Μέγεθος πίνακα κατακερματισμού */
static SymbolEntry ** hashTable;       /* Πίνακας κατακερματισμού        */

static struct Type_tag typeConst [] = {
    { TYPE_VOID,    NULL, 0, 0 },
    { TYPE_INTEGER, NULL, 0, 0 },
    { TYPE_BOOLEAN, NULL, 0, 0 },
    { TYPE_CHAR,    NULL, 0, 0 },
    { TYPE_ANY,     NULL, 0, 0 },
};

const Type typeVoid    = &(typeConst[0]);
const Type typeInteger = &(typeConst[1]);
const Type typeBoolean = &(typeConst[2]);
const Type typeChar    = &(typeConst[3]);
const Type typeAny	   = &(typeConst[4]);


/* ---------------------------------------------------------------------
   ------- Υλοποίηση βοηθητικών συναρτήσεων του πίνακα συμβόλων --------
   --------------------------------------------------------------------- */

typedef unsigned long int HashType;

static HashType PJW_hash (const char * key)
{
    /*
     *  P.J. Weinberger's hashing function. See also:
     *  Aho A.V., Sethi R. & Ullman J.D, "Compilers: Principles,
     *  Techniques and Tools", Addison Wesley, 1986, pp. 433-437.
     */

    const HashType PJW_OVERFLOW =
        (((HashType) 0xf) << (8 * sizeof(HashType) - 4));
    const int PJW_SHIFT = (8 * (sizeof(HashType) - 1));
    
    HashType h, g;
    
    for (h = 0; *key != '\0'; key++) {
        h = (h << 4) + (*key);
        if ((g = h & PJW_OVERFLOW) != 0) {
            h ^= g >> PJW_SHIFT;
            h ^= g;
        }
    }
    return h;
}

void strAppendChar (char * buffer, RepChar c)
{
    switch (c) {
        case '\n':
            strcat(buffer, "\\n");
            break;
        case '\t':
            strcat(buffer, "\\t");
            break;
        case '\r':
            strcat(buffer, "\\r");
            break;
        case '\0':
            strcat(buffer, "\\0");
            break;
        case '\\':
            strcat(buffer, "\\\\");
            break;
        case '\'':
            strcat(buffer, "\\'");
            break;
        case '\"':
            strcat(buffer, "\\\"");
            break;
        default: {
            char s[] = { '\0', '\0' };
            
            *s = c;
            strcat(buffer, s);
        }
    }
}

void strAppendString (char * buffer, RepString str)
{
    const char * s;
    
    for (s = str; *s != '\0'; s++)
        strAppendChar(buffer, *s);
}


/* ---------------------------------------------------------------------
   ------ Υλοποίηση των συναρτήσεων χειρισμού του πίνακα συμβόλων ------
   --------------------------------------------------------------------- */

void initSymbolTable (unsigned int size)
{
    unsigned int i;
    
    /* Διάφορες αρχικοποιήσεις */
    
    currentScope = NULL;
    quadNext     = 1;
    tempNumber   = 1;
    
    /* Αρχικοποίηση του πίνακα κατακερματισμού */
    
    hashTableSize = size;
    hashTable = (SymbolEntry **) new(size * sizeof(SymbolEntry *));
    
    for (i = 0; i < size; i++)
        hashTable[i] = NULL;
}

void destroySymbolTable ()
{
    unsigned int i;
    
    /* Καταστροφή του πίνακα κατακερματισμού */
    
    for (i = 0; i < hashTableSize; i++)
        if (hashTable[i] != NULL)
            destroyEntry(hashTable[i]);

    delete(hashTable);
}

void openScope ()
{
    Scope * newScope = (Scope *) new(sizeof(Scope));

    newScope->negOffset = START_NEGATIVE_OFFSET;
    newScope->parent    = currentScope;
    newScope->entries   = NULL;

    if (currentScope == NULL)
        newScope->nestingLevel = 1;
    else
        newScope->nestingLevel = currentScope->nestingLevel + 1;
    
	//our addition
	newScope->gcHungry = false; 

    currentScope = newScope;
}

void closeScope ()
{
    SymbolEntry * e = currentScope->entries;
    Scope       * t = currentScope;
    
    while (e != NULL) {
        SymbolEntry * next = e->nextInScope;
        
        hashTable[e->hashValue] = e->nextHash;
		/* ATTENTION: We commented the following line to retain SymbolEntries in heap
		 *			  since they are necessary for final code generation
		 */
        //destroyEntry(e);
        e = next;
    }
    
    currentScope = currentScope->parent;
    delete(t);
}

static void insertEntry (SymbolEntry * e)
{
    e->nextHash             = hashTable[e->hashValue];
    hashTable[e->hashValue] = e;
    e->nextInScope          = currentScope->entries;
    currentScope->entries   = e;
}

static SymbolEntry * newEntry (const char * name)
{
    SymbolEntry * e;
    
    /* Έλεγχος αν υπάρχει ήδη στο τρέχον scope */
    
    for (e = currentScope->entries; e != NULL; e = e->nextInScope)
        if (strcmp(name, e->id) == 0) {
            error("Duplicate identifier: %s", name);
            return NULL;
        }

    /* Αρχικοποίηση όλων εκτός: entryType και u */

    e = (SymbolEntry *) new(sizeof(SymbolEntry));
    e->id = (const char *) new(strlen(name) + 1);

    strcpy((char *) (e->id), name);
    e->hashValue    = PJW_hash(name) % hashTableSize;
    e->nestingLevel = currentScope->nestingLevel;
    insertEntry(e);
    return e;
}

SymbolEntry * newVariable (const char * name, Type type)
{
    SymbolEntry * e = newEntry(name);
    
    if (e != NULL) {
        e->entryType = ENTRY_VARIABLE;
        e->u.eVariable.type = type;
        type->refCount++;
        currentScope->negOffset -= sizeOfType(type);
        e->u.eVariable.offset = currentScope->negOffset;
    }
    return e;
}

SymbolEntry * newConstant (const char * name, Type type, ...)
{
    SymbolEntry * e;
    va_list ap;

    union {
        RepInteger vInteger;
        RepBoolean vBoolean;
        RepChar    vChar;
        RepString  vString;
    } value;
    
    va_start(ap, type);
    switch (type->kind) {
        case TYPE_INTEGER:
            value.vInteger = va_arg(ap, RepInteger);
            break;
        case TYPE_BOOLEAN:
            value.vBoolean = va_arg(ap, int);     /* RepBool is promoted */
            break;
        case TYPE_CHAR:
            value.vChar = va_arg(ap, int);        /* RepChar is promoted */
            break;
		case TYPE_IARRAY:
            if (equalType(type->refType, typeChar)) {
                RepString str = va_arg(ap, RepString);
                
                value.vString = (const char *) new(strlen(str) + 1);
                strcpy((char *) (value.vString), str);
                break;
            }
		case TYPE_LIST:
			//only nil list can exist as a list constant, no need to parse va_list
			if(strcmp(name,"nil")!=0) internal("newConstant(): invalid list constant");
			break;
        default:
            internal("Invalid type for constant");
    }
    va_end(ap);

    if (name == NULL) {
        char buffer[256];
        
        switch (type->kind) {
            case TYPE_INTEGER:
                sprintf(buffer, "%d", value.vInteger);
                break;
            case TYPE_BOOLEAN:
                if (value.vBoolean)
                    sprintf(buffer, "true");
                else
                    sprintf(buffer, "false");
                break;
            case TYPE_CHAR:
                strcpy(buffer, "'");
                strAppendChar(buffer, value.vChar);
                strcat(buffer, "'");
                break;
            case TYPE_IARRAY:
                strcpy(buffer, "\"");
                strAppendString(buffer, value.vString);
                strcat(buffer, "\"");           
        }
		/* Our addition: Construct only one instance for each different value */
		e = lookupEntry(buffer,LOOKUP_ALL_SCOPES,false);
		if(e==NULL)	
	        e = newEntry(buffer);
		else
			return e;
    }
    else{
		/* Our addition: Construct only one instance for each different value */
		e = lookupEntry(name,LOOKUP_ALL_SCOPES,false);
		if(e==NULL)	
			e = newEntry(name);
		else 
			return e;
    }

	#ifdef DEBUG
	printf("newConstant: ");
	if(e==NULL) {printf("is null\n"); return NULL;}
	printType(type);
	switch (type->kind) {
		case TYPE_INTEGER:
			printf("%d",value.vInteger);
			break;
		case TYPE_BOOLEAN:
			printf("%d",value.vBoolean);
			break;
		case TYPE_CHAR:
			printf("%c",value.vChar);
			break;
		case TYPE_IARRAY:
			printf("%s",value.vString);
		case TYPE_LIST:
			printf("nil");
	}
	printf(" --\n");
	#endif
	
    if (e != NULL) {
        e->entryType = ENTRY_CONSTANT;
        e->u.eConstant.type = type;
        type->refCount++;
        switch (type->kind) {
            case TYPE_INTEGER:
                e->u.eConstant.value.vInteger = value.vInteger;
                break;
            case TYPE_BOOLEAN:
                e->u.eConstant.value.vBoolean = value.vBoolean;
                break;
            case TYPE_CHAR:
                e->u.eConstant.value.vChar = value.vChar;
                break;
			case TYPE_IARRAY:
                e->u.eConstant.value.vString = value.vString;
				break;
			case TYPE_LIST:
				break; //no need to provide a value, only nil constant existent for lists
        }
    }
    return e;
}




SymbolEntry * newFunction (const char * name)
{
    SymbolEntry * e = lookupEntry(name, LOOKUP_CURRENT_SCOPE, false);

    if (e == NULL) {
        e = newEntry(name);
        if (e != NULL) {
            e->entryType = ENTRY_FUNCTION;
            e->u.eFunction.isForward = false;
            e->u.eFunction.pardef = PARDEF_DEFINE;
            e->u.eFunction.firstArgument = e->u.eFunction.lastArgument = NULL;
            e->u.eFunction.resultType = NULL;
        }
        return e;
    }
    else if (e->entryType == ENTRY_FUNCTION && e->u.eFunction.isForward) {
        e->u.eFunction.isForward = false;
        e->u.eFunction.pardef = PARDEF_CHECK;
        e->u.eFunction.lastArgument = NULL;
        return e;
    }
    else {
       error("Duplicate identifier: %s", name);
       return NULL;
    }
}

SymbolEntry * newParameter (const char * name, Type type,
                            PassMode mode, SymbolEntry * f)
{
    SymbolEntry * e;
    
    if (f->entryType != ENTRY_FUNCTION)
        internal("Cannot add a parameter to a non-function");
    switch (f->u.eFunction.pardef) {
        case PARDEF_DEFINE:
            e = newEntry(name);
            if (e != NULL) {
                e->entryType = ENTRY_PARAMETER;
                e->u.eParameter.type = type;
                type->refCount++;
                e->u.eParameter.mode = mode;
                e->u.eParameter.next = NULL;
            }
            if (f->u.eFunction.lastArgument == NULL)
                f->u.eFunction.firstArgument = f->u.eFunction.lastArgument = e;
            else {
                f->u.eFunction.lastArgument->u.eParameter.next = e;
                f->u.eFunction.lastArgument = e;
            }
            return e;            
        case PARDEF_CHECK:
            e = f->u.eFunction.lastArgument;
            if (e == NULL)
                e = f->u.eFunction.firstArgument;
            else
                e = e->u.eParameter.next;
            if (e == NULL)
                error("More parameters than expected in redeclaration "
                      "of function %s", f->id);
            else if (!equalType(e->u.eParameter.type, type))
                error("Parameter type mismatch in redeclaration "
                      "of function %s", f->id);
            else if (e->u.eParameter.mode != mode)
                error("Parameter passing mode mismatch in redeclaration "
                      "of function %s", f->id);
            else if (strcmp(e->id, name) != 0)
                error("Parameter name mismatch in redeclaration "
                      "of function %s", f->id);
            else
                insertEntry(e);
            f->u.eFunction.lastArgument = e;
            return e;
        case PARDEF_COMPLETE:
            fatal("Cannot add a parameter to an already defined function");
    }
    return NULL;
}

static unsigned int fixOffset (SymbolEntry * args)
{
    if (args == NULL)
        return 0;
    else {
        unsigned int rest = fixOffset(args->u.eParameter.next);
        
        args->u.eParameter.offset = START_POSITIVE_OFFSET + rest;
        if (args->u.eParameter.mode == PASS_BY_REFERENCE)
            return rest + 2;
        else
            return rest + sizeOfType(args->u.eParameter.type);
    }
}

void forwardFunction (SymbolEntry * f)
{
    if (f->entryType != ENTRY_FUNCTION)
        internal("Cannot make a non-function forward");
    f->u.eFunction.isForward = true;
}

void endFunctionHeader (SymbolEntry * f, Type type)
{
	static int maxSerialNum = - LF_NUM;

    if (f->entryType != ENTRY_FUNCTION)
        internal("Cannot end parameters in a non-function");
    switch (f->u.eFunction.pardef) {
        case PARDEF_COMPLETE:
            internal("Cannot end parameters in an already defined function");
            break;
        case PARDEF_DEFINE:
			//4 next lines are our addition
			f->u.eFunction.serialNum = maxSerialNum++;
            f->u.eFunction.posOffset = fixOffset(f->u.eFunction.firstArgument);
			f->u.eFunction.gcHungry = false;
            f->u.eFunction.resultType = type;
            type->refCount++;
            break;
        case PARDEF_CHECK:
            if ((f->u.eFunction.lastArgument != NULL &&
                 f->u.eFunction.lastArgument->u.eParameter.next != NULL) ||
                (f->u.eFunction.lastArgument == NULL &&
                 f->u.eFunction.firstArgument != NULL))
                error("Fewer parameters than expected in redeclaration "
                      "of function %s", f->id);
            if (!equalType(f->u.eFunction.resultType, type))
                error("Result type mismatch in redeclaration of function %s",
                      f->id);
            break;
    }
    f->u.eFunction.pardef = PARDEF_COMPLETE;
}

SymbolEntry * newTemporary (Type type)
{
    char buffer[10];
    SymbolEntry * e;

    sprintf(buffer, "$%d", tempNumber);
    e = newEntry(buffer);
    
    if (e != NULL) {
        e->entryType = ENTRY_TEMPORARY;
        e->u.eVariable.type = type;
        type->refCount++;
        currentScope->negOffset -= sizeOfType(type);
        e->u.eTemporary.offset = currentScope->negOffset;
        e->u.eTemporary.number = tempNumber++;
    }
    return e;
}

void destroyEntry (SymbolEntry * e)
{
    SymbolEntry * args;
    
    switch (e->entryType) {
        case ENTRY_VARIABLE:
            destroyType(e->u.eVariable.type);
            break;
        case ENTRY_CONSTANT:
            if (e->u.eConstant.type->kind == TYPE_IARRAY)
                delete((char *) (e->u.eConstant.value.vString));
            destroyType(e->u.eConstant.type);
            break;
        case ENTRY_FUNCTION:
            args = e->u.eFunction.firstArgument;
            while (args != NULL) {
                SymbolEntry * p = args;
                
                destroyType(args->u.eParameter.type);
                delete((char *) (args->id));
                args = args->u.eParameter.next;
                delete(p);
            }
            destroyType(e->u.eFunction.resultType);
            break;
        case ENTRY_PARAMETER:
            /* Οι παράμετροι καταστρέφονται μαζί με τη συνάρτηση */
            return;
        case ENTRY_TEMPORARY:
            destroyType(e->u.eTemporary.type);
            break;
    }
    delete((char *) (e->id));
    delete(e);        
}

SymbolEntry * lookupEntry (const char * name, LookupType type, bool err)
{
    unsigned int  hashValue = PJW_hash(name) % hashTableSize;
    SymbolEntry * e         = hashTable[hashValue];
    
    switch (type) {
        case LOOKUP_CURRENT_SCOPE:
            while (e != NULL && e->nestingLevel == currentScope->nestingLevel)
                if (strcmp(e->id, name) == 0)
                    return e;
                else
                    e = e->nextHash;
            break;
        case LOOKUP_ALL_SCOPES:
            while (e != NULL)
                if (strcmp(e->id, name) == 0)
                    return e;
                else
                    e = e->nextHash;
            break;
    }
    
    if (err){
        error("Unknown identifier: %s", name);
		exit(1);
	}
    return NULL;
}

Type typeIArray (Type refType)
{
    Type n = (Type) new(sizeof(struct Type_tag));

    n->kind     = TYPE_IARRAY;
    n->refType  = refType;
    n->refCount = 1;
    
    refType->refCount++;

    return n;
}

Type typePointer(Type refType)
{
	Type n = (Type) new(sizeof(struct Type_tag));

	n->kind		= TYPE_POINTER;
	n->refType	= refType;
	n->refCount = 1;

	refType->refCount++;

	return n;
}

Type typeList (Type refType)
{
	Type n = (Type) new(sizeof(struct Type_tag));

	n->kind		= TYPE_LIST;
	n->refType	= refType;
	n->refCount = 1;

	refType->refCount++;

	return n;
}


void destroyType (Type type)
{
    switch (type->kind) {
        case TYPE_IARRAY:
			;
    }
}

unsigned int sizeOfType (Type type)
{
    switch (type->kind) {
        case TYPE_VOID:
            internal("Type void has no size");
            break;
        case TYPE_INTEGER:
        case TYPE_IARRAY:
		case TYPE_POINTER:
		case TYPE_LIST:
			return 2;
		case TYPE_ANY:
        case TYPE_BOOLEAN:
        case TYPE_CHAR:
            return 1;
    }
    return 0;
}

bool equalType (Type type1, Type type2)
{
	/* We added: a recursive typecheking for lists and arrays and
	 *			 compatibility with TYPE_ANY that is always equal with any type except typeVoid
	 */
	if((type1->kind==TYPE_ANY && type2->kind!=TYPE_VOID) || (type2->kind==TYPE_ANY && type1->kind!=TYPE_VOID))
		return true;

    if (type1->kind != type2->kind)
        return false;
    switch (type1->kind) {
        case TYPE_IARRAY:
			return equalType(type1->refType,type2->refType);
		case TYPE_POINTER:
			return equalType(type1->refType,type2->refType);
		case TYPE_LIST:
			return equalType(type1->refType,type2->refType);
    }
    return true;        
}

void printType (Type type)
{
    if (type == NULL) {
        printf("<undefined>");
        return;
    }
    
    switch (type->kind) {
        case TYPE_VOID:
            printf("void");
            break;
        case TYPE_INTEGER:
            printf("integer");
            break;
        case TYPE_BOOLEAN:
            printf("boolean");
            break;
        case TYPE_CHAR:
            printf("char");
            break;
        case TYPE_IARRAY:
            printf("array of ");
            printType(type->refType);
            break;
		case TYPE_POINTER:
			printf("pointer to ");
			printType(type->refType);
			break;
		case TYPE_LIST:
			printf("list of ");
			printType(type->refType);
			break;
		case TYPE_ANY:
			printf("any type, (strictly for lists) ");
			break;
    }
}


Type getType(SymbolEntry * s)
{
	if(s==NULL) internal("getType(): SymbolEntry arg is NULL");
	switch(s->entryType){
		case ENTRY_CONSTANT:	return s->u.eConstant.type;
		case ENTRY_VARIABLE:	return s->u.eVariable.type;
		case ENTRY_PARAMETER:	return s->u.eParameter.type;
		case ENTRY_TEMPORARY:	return s->u.eTemporary.type;
		case ENTRY_FUNCTION:	internal("getType(): unsupported ENTRY_FUNCTION");
		default:				internal("getType(): unhandled entry type");
	}
}

int getOffset(SymbolEntry * s)
{
	if(s==NULL) internal("getOffset(): SymbolEntry arg is NULL");
	switch(s->entryType){
		case ENTRY_VARIABLE:	return s->u.eVariable.offset;
		case ENTRY_PARAMETER:	return s->u.eParameter.offset;
		case ENTRY_TEMPORARY:	return s->u.eTemporary.offset;
		case ENTRY_FUNCTION:	internal("geOffset(): unsupported ENTRY_FUNCTION");
		case ENTRY_CONSTANT:	internal("geOffset(): unsupported ENTRY_CONSTANT");
		default:				internal("getOffset(): unhandled entry type");
	}
}

const char * typeToStr (Type type)
{
    if (type == NULL) {
        return "<undefined>";
    }
    
	char buf[256];
    switch (type->kind) {
        case TYPE_VOID:
            return "void";
            break;
        case TYPE_INTEGER:
            return "integer";
            break;
        case TYPE_BOOLEAN:
            return "boolean";
            break;
        case TYPE_CHAR:
            return "char";
            break;
        case TYPE_IARRAY:
			sprintf(buf,"array of %s",typeToStr(type->refType));
			return strdup(buf);
            break;
		case TYPE_POINTER:
			sprintf(buf,"pointer to %s",typeToStr(type->refType));
		case TYPE_LIST:
			sprintf(buf,"list of %s",typeToStr(type->refType));
			return strdup(buf);
			break;
		case TYPE_ANY:
			return "any type, (strictly for lists) ";
			break;
    }
	return "undefined";
}

void printMode (PassMode mode)
{
    if (mode == PASS_BY_REFERENCE)
        printf("var ");
}


bool isLibFunc(SymbolEntry * s)
{
	if(s->entryType!=ENTRY_FUNCTION) internal("final: siLibFunc(): symbol is not of type ENTRY_FUNCTION");
	return (s->u.eFunction.serialNum < 0 ? true : false);
}

bool isCallableFunc(SymbolEntry * s)
{
	if(s->entryType!=ENTRY_FUNCTION) internal("final: siLibFunc(): symbol is not of type ENTRY_FUNCTION");
	return (s->u.eFunction.serialNum >= -LF_CALLABLE_NUM  ? true : false);

}
