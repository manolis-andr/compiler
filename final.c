/******************************************************************************
 
 *  C header file : final.c
 *  Project       : Tony Compiler
 *  Version       : 1.0 alpha
 *  Written by    : Manolis	Androulidakis
 *  Date          : September 28, 2014
 *  Description   : Final code generation
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
#include <stdarg.h>
#include "intermediate.h"
#include "general.h"
#include "symbol.h"
#include "error.h"


/* -------------------------------------------------------------
   --------------- Internal Function Declaration ---------------
   ------------------------------------------------------------- */

void    load            (char * reg, Operand o);
void    loadAddr        (char * reg, Operand o);
void    store           (char * reg, Operand o);
void    getAR           (SymbolEntry * s);
void    updateAL        (SymbolEntry * s);

char *  name            (Operand o);
char *  endof           (Operand o);
char *  label           (Operand o);

void	printConditional(char * instr, Quad q);

void	code			(char * command, char * a1, char * a2);					//print an assembly command 
void	codel			(char * label, char * command, char * a1, char * a2);	//print labels in front
void	codeq			(Quad q);												//print in commented format the original quad
char *  str             (const char *s, ...);
int		elementSize		(Operand o);

/* -------------------------------------------------------------
   ---------------------- Global variables ---------------------
   ------------------------------------------------------------- */

FILE * fout = NULL;
int	fprintStart = 1;

Operand currentUnit;	//the unit whose final code is generated, useful for jumps

/* -------------------------------------------------------------
   ------------------------- Functions -------------------------
   ------------------------------------------------------------- */


void printFinal() /*FIXME: more cases remaining */
{
	int i;
	for(i=fprintStart;i<quadNext;i++)
	{
		Operand x = q[i].x;
		Operand y = q[i].y;
		Operand z = q[i].z;
		codeq(q[i]);
		codel(label(oL(i)),NULL,NULL,NULL);
		switch(q[i].op){
			case O_ASSIGN:
				load("bx",x);
				store("bx",z);
				break;
			case O_ARRAY:
				load("ax",y);
				code("mov","cx",str("%d",elementSize(x)));
				code("imul","cx",NULL);
				loadAddr("cx",x);
				code("add","ax","cx");
				store("ax",z);
				break;
			case O_ADD:
				load("ax",x);
				load("dx",y);
				code("add","ax","dx");
				store("ax",z);
				break;
			case O_SUB:
				load("ax",x);
				load("dx",y);
				code("sub","ax","dx");
				store("ax",z);
				break;
			case O_MULT:
				load("ax",x);
				load("cx",y);
				code("imul","cx",NULL);
				store("ax",z);
				break;
			case O_DIV:
				load("ax",x);
				code("cwd",NULL,NULL);
				load("cx",y);
				code("idiv","cx",NULL);
				store("ax",z);
				break;
			case O_MOD:
				load("ax",x);
				code("cwd",NULL,NULL);
				load("cx",y);
				code("idiv","cx",NULL);
				store("dx",z);
				break;
			case O_EQ:
				printConditional("je",q[i]);	
				break;
			case O_NE:
				printConditional("jne",q[i]);	
				break;
			case O_LT:
				printConditional("jl",q[i]);	
				break;
			case O_GT:
				printConditional("jg",q[i]);	
				break;
			case O_LE:
				printConditional("jle",q[i]);	
				break;
			case O_GE:
				printConditional("jge",q[i]);	
				break;
			case O_IFB:
				load("al",x);
				code("or","al","al");
				code("jnz",label(z),NULL);
				break;
			case O_JUMP:
				code("jmp",label(z),NULL);
				break;
			case O_UNIT: 
				codel(name(x),"proc","near",NULL);
				code("push","bp",NULL);
				code("mov","bp","sp");
				int localSize = - currentScope->negOffset;
				code("sub","sp",str("%d",localSize));
				//it is always the first quad to be printed in a block, so we can now save the name of the block
				currentUnit = x;
				break;
			case O_ENDU:
				codel(endof(x),"mov","sp","bp");
				code("pop","bp",NULL);
				code("ret",NULL,NULL);
				codel(name(x),"endp",NULL,NULL);
				break;
			case O_CALL:
				{SymbolEntry * s = lookupEntry(z->name,LOOKUP_ALL_SCOPES,false);
				if(s==NULL || s->entryType!=ENTRY_FUNCTION) internal("final: printFinal(): no function named %s in open scopes",z->name);
				if(equalType(s->u.eFunction.resultType,typeVoid))
					code("sub","sp","2");
				updateAL(s);
				code("call",str("near ptr %s",name(z)),NULL);
				int paramSize = s->u.eFunction.posOffset;
				code("add","sp",str("%d",paramSize+4));
				}
				break;
			case O_RET:
				code("jmp",endof(currentUnit),NULL);
				break;
			case O_PAR:/*FIXME: more cases here */
				if(x==oV){
					load("ax",y);
					code("push","ax",NULL);
				}
				else if(x==oR || x==oRET){
					loadAddr("si",y);
					code("push","si",NULL);
				}
				break;
			default:
				internal("final: printFinal(): unhandled Operator case");
		}
	}
	fprintStart=quadNext;
}

/*	1. Είναι καλή δομή ο πίνακας για αποθήκευση των τετράδων ή δεν βολεύει στην βελτιστοποίηση του ενδιάμεσου κώδικα; (αν πρέπει να αναδιατάσσω και να
		διαγράφω/προσθέτω εντολές ο πίνακας δεν είναι το καλύτερο δυνατό).
	2. Είναι δυνατόν να βελτιστοποιηθεί ο ενδιάμεσος κώδικας κατά δομικά μπλοκ (συναρτήσεις) ή πρέπει να γίνει εξ ολοκλήρου η διαδικασία, με όλο
		τον ενδιάμεσο κώδικα διαθέσιμο; Αν είναι δυνατόν, τότε δεν χρειάζεται να αποθηκεύουμε κάπου αλλού τις τετράδες και θα καλούμε τον optimizer 
		και τον final code generator ακριβώς πριν το closeScope().
	3. Να ξεκαθαρίσω ποιά πρέπει να είναι η βλετιστοποίηση στον τελικό κώδικα γιατί αν δεν χρειάζεται καθόλου τότε μπορώ να τυπώνω κατευθείαν τις 
		εντολές. Ειδάλλως θα πρέπει να φτιάξω struct και να τις αποθηκεύω πάλι σε ένα πίνακα/λίστα στην μνήμη, και αφού κάνω το optimize να τυπώνω.
*/

void skeletonBegin(char * progname){
	fprintf(fout,
			"xseg\tsegment\tpublic 'code'\n"
			"\tassume\tcs:xseg, ds:xseg, ss:sxeg\n"
			"\torg\t100h\n"
			"main\tproc\tnear\n"
			"\tcall\tnear ptr %s\n"
			"\tmov\tax, 4C00h\n"
			"\tint\t21ha\n"
			"main\tendp\n"
			,name(oU(progname)));
}

void skeletonEnd(){
	fprintf(fout,
			"xseg\tends\n"
			"\tend\tmain\n"
			);
}


void code(char * command,char * a1, char * a2)				
{	
	if(command!=NULL)	fprintf(fout,"\t%s",command);
	if(a1!=NULL)		fprintf(fout,"\t%s",a1);
	if(a2!=NULL)		fprintf(fout,", %s",a2); 
	fprintf(fout,"\n");
}

void codel(char * label,char * command,char * a1, char * a2)
{ 
	if(label!=NULL)		fprintf(fout,"%s:",label);
	code(command,a1,a2);
}

void codeq(Quad q)	{ fprintf(fout,";;; %d: %s, %s, %s, %s\n",q.num,otos(q.op),q.x->name,q.y->name,q.z->name); }

/* ------------------ Helper ----------------------- */


void load(char * r, Operand o){

	switch(o->type){
		
		char * size;
		int offset;
		SymbolEntry * s;
		case OPERAND_SYMBOL:
			s = o->u.symbol;
			switch(s->entryType){

				case ENTRY_CONSTANT:
					if(equalType(s->u.eConstant.type,typeInteger))		code("mov",r,str("%d",s->u.eConstant.value.vInteger));
					else if(strcmp(o->name,"true")==0)					code("mov",r,"1");
					else if(strcmp(o->name,"false")==0)					code("mov",r,"0");
					else if(equalType(s->u.eConstant.type,typeChar))	code("mov",r,str("%d",s->u.eConstant.value.vChar));	
					else if(strcmp(o->name,"nil")==0)					code("mov",r,"0");
					else												internal("final: load: unhandled case in constants");
					break;

				case ENTRY_VARIABLE:
					offset = s->u.eVariable.offset;
					if(sizeOfType(s->u.eVariable.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)						//local
						code("mov",r,str("%s ptr [bp%d]",size,offset));	
					else if(s->nestingLevel<currentScope->nestingLevel){				//non-local
						getAR(s);
						code("mov",r,str("%s ptr [si%d]",size,offset));
					}
					else
						internal("final: load: nesting level of variable greater than current scope!");
					break;

				case ENTRY_TEMPORARY:
					offset = s->u.eTemporary.offset;
					if(sizeOfType(s->u.eTemporary.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)						//local
						code("mov",r,str("%s ptr [bp%d]",size,offset));	
					else if(s->nestingLevel<currentScope->nestingLevel){				//non-local
						getAR(s);
						code("mov",r,str("%s ptr [si%d]",size,offset));
					}
					else
						internal("final: load: nesting level of temporary greater than current scope!");
					break;

				case ENTRY_PARAMETER:
					offset = s->u.eParameter.offset;
					if(sizeOfType(s->u.eParameter.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)					
						if(s->u.eParameter.mode==PASS_BY_VALUE)							//local - pass by value
							code("mov",r,str("%s ptr [bp+%d]",size,offset));
						else															//local - pass by reference
							{code("mov","si",str("word ptr [bp+%d]",offset));	code("mov",r,str("%s ptr [si]",size));}
					else if(s->nestingLevel<currentScope->nestingLevel)					//non-local - pass by value
						if(s->u.eParameter.mode==PASS_BY_VALUE)
							{getAR(s);	code("mov",r,str("%s ptr [si+%d]",size,offset));}
						else															//non-local - pass by reference
							{getAR(s);	code("mov","si",str("word ptr [si+%d]",offset));	code("mov",r,str("%s ptr [si]",size));}
					else
						internal("final: load: nesting level of temporary greater than current scope!");
					break;

				case ENTRY_FUNCTION:
					internal("final: load: operand cannot be a function"); break;
				default:
					internal("final: load: unhandled case for OPERAND_SYMBOL");
			}
			break;
		
		case OPERAND_DEREFERENCE:
			if(sizeOfType(o->u.symbol->u.eTemporary.type)==1) size="byte"; else size="word";
			load("di",o);
			code("mov",r,str("%s ptr [di]",size));
			break;
		case OPERAND_ADDRESS:
			loadAddr(r,o);
			break;
		default:
			internal("final: load: unhandled operand type (type=%d)",o->type);
	}
}


void loadAddr(char * r,Operand o)
{	
	switch(o->type){
		
		char * size;
		int offset;
		SymbolEntry * s;
		case OPERAND_SYMBOL:
			s = o->u.symbol;
			switch(s->entryType){

				case ENTRY_CONSTANT:
					internal("final: loadAddr: strings not supported yet");
					if(equalType(s->u.eConstant.type,typeInteger))		code("mov",r,str("%d",s->u.eConstant.value.vInteger));
					else												internal("final: loadAddr: unhandled case in constants");
					break;

				case ENTRY_VARIABLE:
					offset = s->u.eVariable.offset;
					if(sizeOfType(s->u.eVariable.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)						//local
						code("lea",r,str("%s ptr [bp%d]",size,offset));	
					else if(s->nestingLevel<currentScope->nestingLevel){				//non-local
						getAR(s);
						code("lea",r,str("%s ptr [si%d]",size,offset));
					}
					else
						internal("final: loadAddr: nesting level of variable greater than current scope!");
					break;

				case ENTRY_TEMPORARY:
					offset = s->u.eTemporary.offset;
					if(sizeOfType(s->u.eTemporary.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)						//local
						code("lea",r,str("%s ptr [bp%d]",size,offset));	
					else if(s->nestingLevel<currentScope->nestingLevel){				//non-local
						getAR(s);
						code("lea",r,str("%s ptr [si%d]",size,offset));
					}
					else
						internal("final: loadAddr: nesting level of temporary greater than current scope!");
					break;

				case ENTRY_PARAMETER:
					offset = s->u.eParameter.offset;
					if(sizeOfType(s->u.eParameter.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)					
						if(s->u.eParameter.mode==PASS_BY_VALUE)							//local - pass by value
							code("lea",r,str("%s ptr [bp+%d]",size,offset));
						else															//local - pass by reference
							code("mov",r,str("word ptr [bp+%d]",offset));
					else if(s->nestingLevel<currentScope->nestingLevel)					//non-local - pass by value
						if(s->u.eParameter.mode==PASS_BY_VALUE)
							{getAR(s);	code("lea",r,str("%s ptr [si+%d]",size,offset));}
						else															//non-local - pass by reference
							{getAR(s);	code("mov",r,str("word ptr [si+%d]",offset));}
					else
						internal("final: loadAddr: nesting level of temporary greater than current scope!");
					break;

				case ENTRY_FUNCTION:
					internal("final: loadAddr: operand cannot be a function"); break;
				default:
					internal("final: loadAddr: unhandled case for OPERAND_SYMBOL");
			}
			break;
		
		case OPERAND_DEREFERENCE:
			load(r,o);
			break;

		default:
			internal("final: load: unhandled operand type (type=%d)",o->type);
	}
}

void store(char *r, Operand o)
{
	switch(o->type){
		
		char * size;
		int offset;
		SymbolEntry * s;
		case OPERAND_SYMBOL:
			s = o->u.symbol;
			switch(s->entryType){

				case ENTRY_VARIABLE:
					offset = s->u.eVariable.offset;
					if(sizeOfType(s->u.eVariable.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)						//local
						code("mov",str("%s ptr [bp%d]",size,offset),r);	
					else if(s->nestingLevel<currentScope->nestingLevel){				//non-local
						getAR(s);
						code("mov",str("%s ptr [si%d]",size,offset),r);
					}
					else
						internal("final: store: nesting level of variable greater than current scope!");
					break;

				case ENTRY_TEMPORARY:
					offset = s->u.eTemporary.offset;
					if(sizeOfType(s->u.eTemporary.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)						//local
						code("mov",str("%s ptr [bp%d]",size,offset),r);	
					else if(s->nestingLevel<currentScope->nestingLevel){				//non-local
						getAR(s);
						code("mov",str("%s ptr [si%d]",size,offset),r);
					}
					else
						internal("final: store: nesting level of temporary greater than current scope!");
					break;

				case ENTRY_PARAMETER:
					offset = s->u.eParameter.offset;
					if(sizeOfType(s->u.eParameter.type)==1) size="byte"; else size="word";
					if(s->nestingLevel==currentScope->nestingLevel)					
						if(s->u.eParameter.mode==PASS_BY_VALUE)							//local - pass by value
							code("mov",str("%s ptr [bp+%d]",size,offset),r);
						else															//local - pass by reference
							{code("mov","si",str("word ptr [bp+%d]",offset));	code("mov",str("%s ptr [si]",size),r);}
					else if(s->nestingLevel<currentScope->nestingLevel)					//non-local - pass by value
						if(s->u.eParameter.mode==PASS_BY_VALUE)
							{getAR(s);	code("mov",str("%s ptr [si+%d]",size,offset),r);}
						else															//non-local - pass by reference
							{getAR(s);	code("mov","si",str("word ptr [si+%d]",offset));	code("mov",str("%s ptr [si]",size),r);}
					else
						internal("final: store: nesting level of temporary greater than current scope!");
					break;

				case ENTRY_FUNCTION:
					internal("final: store: operand cannot be a function"); break;
				case ENTRY_CONSTANT:
					internal("final: store: operand cannot be a constant"); break;
				default:
					internal("final: store: unhandled case for OPERAND_SYMBOL");
			}
			break;

		case OPERAND_RESULT:
			code("mov","si","word ptr [bp+6]");
			code("mov","word ptr [si]",r);
			break;

		case OPERAND_DEREFERENCE:
			if(sizeOfType(o->u.symbol->u.eTemporary.type)==1) size="byte"; else size="word";
			load("di",o);
			code("mov",str("%s ptr [di]",size),r);
			break;
	
		default:
			internal("final: store: unhandled operand type (type=%d)",o->type);
	}
}

void getAR(SymbolEntry * s)
{
	if(s->entryType!=ENTRY_FUNCTION) internal("final: getAR() should be called with an SymbolEntry * of EntryType ENTRY_FUNCTION");
	code("mov","si","word ptr [bp+4]");
	int i;
	int links = currentScope->nestingLevel - s->nestingLevel - 1;
	for(i=0;i<links;i++)
		code("mov","si","word ptr [si+4]");
}


void updateAL(SymbolEntry * s)
{
	if(s->entryType!=ENTRY_FUNCTION) internal("final: updateAL() should be called with an Operand that contains an ENTRY_FUNCTION symbol");
	int np = currentScope->nestingLevel - 1;	//caller function nesting level
	int nx = s->nestingLevel;					//callee function nesting level
	#ifdef DEBUG
	printf("updateAL: calling %s: n.caller=%d, n.callee=%d\n",s->id,np,nx);
	#endif
	if(np<nx)
		code("push","bp",NULL);
	else if (np == nx)
		code("push","word ptr [bp+4]",NULL);
	else
		{getAR(s);	code("push","word ptr [si+4]",NULL);}
}


//support up to 9999 quads and 999 functions
#ifndef LABEL_BUFFER_SIZE
#define LABEL_BUFFER_SIZE 6
#endif
char * label(Operand o)
{
	if(o->type!=OPERAND_QLABEL) internal("final: label() should be called with an OPERAND_QLABEL Operand");
	char * buf = (char *) new(LABEL_BUFFER_SIZE*sizeof(char));
	sprintf(buf,"@%d",o->u.quadLabel);
	return buf;
}

char * name(Operand o)
{
	if(o->type!=OPERAND_UNIT) internal("final: name() must be called with an OPERAND_UNIT Operand");
	const char * p = o->name;
	int num  = o->u.unitNum; 
	char * buf = (char *) new((strlen(p)+LABEL_BUFFER_SIZE)*sizeof(char));
	if(num>=0)	sprintf(buf,"_%s_%d",p,num);	//ordinary function	
	else		sprintf(buf,"_%s",p);			//run-time Library Function
	return buf;
}

char * endof(Operand o)
{
	if(o->type!=OPERAND_UNIT) internal("final: endof() must be called with an OPERAND_UNIT Operand");
	const char * p = o->name;
	int num  = o->u.unitNum; 
	char * buf = (char *) new((strlen(p)+LABEL_BUFFER_SIZE)*sizeof(char));
	if(num>=0)	sprintf(buf,"@%s_%d",p,num);	//ordinary function	
	else		internal("final: endof called in a runtime library function");
	return buf;
}


void printConditional(char * instr,Quad q)
{				
	load("ax",q.x);
	load("dx",q.y);
	code("cmp","ax","dx");
	if(q.z->type!=OPERAND_QLABEL) internal("final: printConditional(): Operand z must be of type OPERAND_QLABEL");
	code(instr,label(q.z),NULL);
}


#ifndef STR_BUFFER_SIZE
#define STR_BUFFER_SIZE	18
#endif
char * str(const char *s,...)
{
	va_list ap;
	char * string = (char *) new(STR_BUFFER_SIZE*sizeof(char));
	va_start(ap,s);
	vsprintf(string,s,ap);
	va_end(ap);
	return string;
}

//return the size of the element of an array (array is given as an Operand)
int elementSize(Operand o)
{
	if(o->type!=OPERAND_SYMBOL) internal("final: elementSize() operand in call must be an OPERAND_SYMBOL Operand"); 
	SymbolEntry * s = o->u.symbol;
	Type type;
	switch(s->entryType){
		case ENTRY_VARIABLE:	type = s->u.eVariable.type;		break;
		case ENTRY_PARAMETER:	type = s->u.eParameter.type;	break;
		case ENTRY_TEMPORARY:	type = s->u.eTemporary.type;	break;
		default:				internal("final: elementSize(): unhandled case");
	}
	if(!equalType(type,typeIArray(typeAny))) internal("final: elementSize() type of Operand is not an array");
	return sizeOfType(type->refType);
}


