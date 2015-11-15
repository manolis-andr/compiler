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


/* ----------------------------------------------------------- 
   ---------------- Constant definitions ---------------------  
   ----------------------------------------------------------- */

#define STRINGS_MAX				128		/* maximum number of string literals in a tony program */

#define STRING_LABEL_BUF_SIZE	9		/* bytes needed to buffer a string label in a char array. Limits string literals to 9999. */
#define LABEL_BUF_SIZE			6		/* bytes needed to buffer a quad or a function label in a char array. Limits to 9999 quads & 999 functions */
#define STR_BUF_SIZE			20		/* bytes allocated for the return buffer of str function */

/* Number of string literals in a tony program supported: min{STRINGS_MAX,10^(STRING_LABEL_SIZE-5)} */

/* For buf sizes, add one to increase number supported by a factor of 10 */

#define PRINTABLE_ASCII(CHAR) ((CHAR)>31 ? true : false)


/* ----------------------------------------------------------- 
   ---------------- used from lexer -------------------------   */
/* ----------------------------------------------------------- */
int		fixChar			(char *, int * shift);	

/* -------------------------------------------------------------
   -------------- Internal Function Declaration ----------------
   ------------------------------------------------------------- */

void	code			(char * command, char * a1, char * a2);								//print an assembly command 
void	codel			(char * label, char * command, char * a1, char * a2, bool colon);	//print labels in front
void	codeq			(Quad q);															//print in commented format the original quad

void    load            (char * reg, Operand o);
void    loadAddr        (char * reg, Operand o);
void    store           (char * reg, Operand o);
void    getAR           (SymbolEntry * s);
void    updateAL        (SymbolEntry * s);

char *  name            (Operand o);
char *  endof           (Operand o);
char *  label           (Operand o);

void	printConditional(char * instr, Quad q);

void	insertExtern	(char * func);
void	printExtern		();

char *	insertString	(SymbolEntry *s);
void	printStrings	();
char *	fixString		(char * str);

char *  str             (const char *s, ...);
int		typeSize		(Operand o);
int		refTypeSize		(Operand o);

/* -------------------------------------------------------------
   ---------------------- Global variables ---------------------
   ------------------------------------------------------------- */

FILE * fout = NULL;
int	fprintStart = 1;

char *	extrn[LF_NUM];
int		extrnNum = 0;

char *	strings[STRINGS_MAX];	/* FIXME: array could be converted to a Queue for felxibility */
int		stringsNum = 0;

Operand currentUnit;	//the unit whose final code is generated, useful for jumps


/* -------------------------------------------------------------
   -------------------- Public Functions -----------------------
   ------------------------------------------------------------- */


void printFinal() 
{
	int i;
	for(i=fprintStart;i<quadNext;i++)
	{
		Quad qd = q[INDEX(i)];
		if(qd.num<0) continue; //quad has been removed by optimizer
		Operand x = qd.x;
		Operand y = qd.y;
		Operand z = qd.z;
		codeq(qd);
		codel(label(oL(i)),NULL,NULL,NULL,true);
		switch(qd.op){
			case O_ASSIGN:
				if(typeSize(x)==1){
					load("bl",x);
					store("bl",z);
				} else if(typeSize(x)==2){
					load("bx",x);
					store("bx",z);
				} else internal("final: printFinal(): unhandled type size case");
				break;
			case O_ARRAY:
				load("ax",y);
				code("mov","cx",str("%d",refTypeSize(x)));
				code("imul","cx",NULL);
				load("cx",x);	//ATTENTION: we modified this. In theory it is loadAddress("cx",x)
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
				printConditional("je",qd);	
				break;
			case O_NE:
				printConditional("jne",qd);	
				break;
			case O_LT:
				printConditional("jl",qd);	
				break;
			case O_GT:
				printConditional("jg",qd);	
				break;
			case O_LE:
				printConditional("jle",qd);	
				break;
			case O_GE:
				printConditional("jge",qd);	
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
				codel(name(x),"proc","near",NULL,false);
				code("push","bp",NULL);
				code("mov","bp","sp");
				int localSize = - currentScope->negOffset;
				code("sub","sp",str("%d",localSize));
				//it is always the first quad to be printed in a block, so we can now save the name of the block
				currentUnit = x;
				break;
			case O_ENDU:
				codel(endof(x),"mov","sp","bp",true);
				code("pop","bp",NULL);
				code("ret",NULL,NULL);
				codel(name(x),"endp",NULL,NULL,false);
				break;
			case O_CALL:
				if(z->type!=OPERAND_UNIT) internal("final: printFinal(): operand z must be an OPERAND_UNIT Operand");
				SymbolEntry * s = z->u.symbol;
				if(equalType(s->u.eFunction.resultType,typeVoid))
					code("sub","sp","2");
				updateAL(s);
				if(isLibFunc(s)) insertExtern(name(z));	//if the function is a library function  we must inlcude an extrn declaration at the end
				code("call",str("near ptr %s",name(z)),NULL);
				int paramSize = s->u.eFunction.posOffset;
				code("add","sp",str("%d",paramSize+4));
				break;
			case O_RET:
				code("jmp",endof(currentUnit),NULL);
				break;
			case O_PAR:
				if(y==oV){
					if(typeSize(x)==1) {
						load("al",x);
						code("sub","sp","1");
						code("mov","si","sp");
						code("mov","byte ptr [si]","al");
					} else if(typeSize(x)==2){
						load("ax",x);
						code("push","ax",NULL);
					} else internal("final: printFinal(): unhandled type size case");
				}
				else if(y==oR || y==oRET){
					loadAddr("si",x);
					code("push","si",NULL);
				}
				break;
			default:
				internal("final: printFinal(): unhandled Operator case");
		}
	}
	fprintStart=quadNext;
}


void skeletonBegin(char * progname){
	fprintf(fout,
			"xseg\tsegment\tpublic 'code'\n"
			"\tassume\tcs:xseg, ds:xseg, ss:xseg\n"
			"\torg\t100h\n"
			"main\tproc\tnear\n"
			"\tcall\tnear ptr %s\n"
			"\tmov\tax, 4C00h\n"
			"\tint\t21h\n"
			"main\tendp\n"
			,name(oU(progname)));
}

void skeletonEnd() 
{
	printExtern();
	printStrings();
	fprintf(fout,
			"xseg\tends\n"
			"\tend\tmain\n"
			);
}


/* Printing functions for assembly commands */
/* -------------------------------------------------------- */


void code(char * command,char * a1, char * a2)				
{	
	if(command!=NULL)	fprintf(fout,"\t%s",command);
	if(a1!=NULL)		fprintf(fout,"\t%s",a1);
	if(a2!=NULL)		fprintf(fout,", %s",a2); 
	fprintf(fout,"\n");
}

void codel(char * label,char * command,char * a1, char * a2,bool colon)
{ 
	if(label!=NULL)		fprintf(fout,"%s",label);
	if(colon)			fprintf(fout,":");
	code(command,a1,a2);
}

void codeq(Quad q)	{ fprintf(fout,";;; %d: %s, %s, %s, %s\n",q.num,otos(q.op),q.x->name,q.y->name,q.z->name); }


/* -------------------------------------------------------------
   -------------------- Helper Functions -----------------------
   ------------------------------------------------------------- */


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
					else if(equalType(s->u.eConstant.type,
									typeIArray(typeChar)))				loadAddr(r,o); //strings
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
			if(typeSize(o)==1) size="byte"; else size="word";
			load("di",oS(getSymbol(o)));
			code("mov",r,str("%s ptr [di]",size));
			break;
		case OPERAND_ADDRESS:
			loadAddr(r,oS(getSymbol(o)));
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
					if(equalType(s->u.eConstant.type,typeIArray(typeChar)))		{char * strLabel = insertString(s); if(strLabel==NULL) fatal("loadAddr string is null!"); code("lea",r,str("byte ptr %s",strLabel));}
					else														internal("final: loadAddr: unhandled case in constants");
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
			load(r,oS(getSymbol(o)));
			break;

		default:
			internal("final: load: unhandled operand type (type=%d)",o->type);
	}
	#ifdef DEBUG
	printf("%s out of loadAddr\n",getSymbol(o)->id);
	#endif
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
			if(sizeOfType(s->u.eParameter.type)==1) size="byte"; else size="word";
			code("mov","si","word ptr [bp+6]");
			code("mov",str("%s ptr [si]",size),r);
			break;

		case OPERAND_DEREFERENCE:
			if(typeSize(o)==1) size="byte"; else size="word";
			load("di",oS(getSymbol(o)));
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


//support up to 10^(LABEL_BUF_SIZE-2) quads
char * label(Operand o)
{
	if(o->type!=OPERAND_QLABEL) internal("final: label() should be called with an OPERAND_QLABEL Operand");
	char * buf = (char *) new(LABEL_BUF_SIZE*sizeof(char));
	sprintf(buf,"@%d",o->u.quadLabel);
	return buf;
}

//supports up to 10^(LABEL_BUF_SIZE-3) functions
char * name(Operand o)
{
	if(o->type!=OPERAND_UNIT) internal("final: name() must be called with an OPERAND_UNIT Operand");
	const char * p = o->name; 
	char * buf = (char *) new((strlen(p)+LABEL_BUF_SIZE)*sizeof(char));
	SymbolEntry * s = o->u.symbol;
	int num	= s->u.eFunction.serialNum;
	if(!isLibFunc(s))	sprintf(buf,"_%s_%d",p,num);	//ordinary function	
	else				sprintf(buf,"_%s",p);			//run-time Library Function
	return buf;
}

//supports up to 10^(LABEL_BUF_SIZE-3) functions
char * endof(Operand o)
{
	if(o->type!=OPERAND_UNIT) internal("final: endof() must be called with an OPERAND_UNIT Operand");
	const char * p = o->name;
	char * buf = (char *) new((strlen(p)+LABEL_BUF_SIZE)*sizeof(char));
	SymbolEntry * s = o->u.symbol;
	int num	= s->u.eFunction.serialNum;
	if(!isLibFunc(s))	sprintf(buf,"@%s_%d",p,num);	//ordinary function	
	else				internal("final: endof called in a runtime library function");
	return buf;
}


void printConditional(char * instr,Quad q)
{
	if(typeSize(q.x)==1){
		load("al",q.x);
		load("dl",q.y);
		code("cmp","al","dl");
		if(q.z->type!=OPERAND_QLABEL) internal("final: printConditional(): Operand z must be of type OPERAND_QLABEL");
		code(instr,label(q.z),NULL);
	}
	else if(typeSize(q.x)==2){
		load("ax",q.x);
		load("dx",q.y);
		code("cmp","ax","dx");
		if(q.z->type!=OPERAND_QLABEL) internal("final: printConditional(): Operand z must be of type OPERAND_QLABEL");
		code(instr,label(q.z),NULL);
	}
	else 
		internal("final: printConditional(): unhandled case for type size ");
}


/* Functions for declaration of external library functions */
/* -------------------------------------------------------- */

void insertExtern(char * func)
{
	int i;
	for(i=0;i<extrnNum;i++)
		if(strcmp(func,extrn[i])==0) return; //function already expressed wish to be declared
	extrn[extrnNum++] = func;
}

void printExtern()	{ int i;   for(i=0;i<extrnNum;i++)	fprintf(fout,"\textrn\t%s : proc\n",extrn[i]); }



/* Functions for declaration of string literals */
/* -------------------------------------------------------- */

char * fixString(char * str)
{
	int i,j,shift;
	int length = strlen(str);
	char * buf = (char *) new(length*sizeof(char));
	i = j = 0; 
	while(i<length){
		buf[j++]=fixChar(str+i,&shift);
		i+=shift;
	}
	buf[j]='\0';
	return buf;
}

//support up to STRINGS_MAX strings (limmited to 10^(STRING_LABLE_BUF_SIZE-4)
char * insertString(SymbolEntry * s)
{
#ifdef DEBUG
	printf("entering insertString()\n");
#endif
	if(s->entryType!=ENTRY_CONSTANT || !equalType(s->u.eConstant.type,typeIArray(typeChar))) internal("final: insertString() not called with string");
	if(stringsNum==STRINGS_MAX) fatal("Too many strings declared. Rcompile the compiler by increasing the definition of STRINGS_MAX");
	char * str = fixString(strdup(s->u.eConstant.value.vString));
	strings[stringsNum] = str;
	char * buf = (char *) new(STRING_LABEL_BUF_SIZE*sizeof(char));
	sprintf(buf,"@str%d",stringsNum);
	stringsNum++;
#ifdef DEBUG
	printf("exiting insertString() with stringNum %d and string: %s\n",stringsNum,buf);
#endif
	return buf;
}

void printStrings()
{
	#ifdef DEBUG
	printf("printStrings starting\n");
	#endif

	int i,j;
	for(i=0;i<stringsNum;i++){
		fprintf(fout,"@str%d",i);
		char * buf = strings[i];
		if(buf==NULL) fatal("printStrings(): attempted to print a null string");
		int buflen = strlen(buf);
		bool printableSeq = false;
		/* Note: starting from j=1 and finishing at strlen-1 in order to ommit start and end quotes "str" */
		for(j=1;j<buflen-1;j++){
			if(PRINTABLE_ASCII(buf[j])){
				if(!printableSeq) fprintf(fout,"\tdb\t'"); //this is the first printable char of a printalbe sequence to be printed in new db line
				printableSeq = true;
				fprintf(fout,"%c",buf[j]);
			}
			else{ 
				if(printableSeq) fprintf(fout,"'\n"); //close printable sequence
				fprintf(fout,"\tdb\t%d\n",buf[j]);
				printableSeq = false;
			}
		}
		if(printableSeq) fprintf(fout,"'\n"); //close printable sequence
		fprintf(fout,"\tdb\t0\n");
	}
}


/* Minor Helper Functions */
/* -------------------------------------------------------- */

char * str(const char *s,...)
{
	va_list ap;
	char * string = (char *) new(STR_BUF_SIZE*sizeof(char));
	va_start(ap,s);
	vsprintf(string,s,ap);
	va_end(ap);
	return string;
}

int typeSize(Operand o)
{
	if(o->type!=OPERAND_SYMBOL && o->type!=OPERAND_DEREFERENCE) internal("final: typeSize() operand in call must be an OPERAND_SYMBOL Operand"); 
	SymbolEntry * s = o->u.symbol;
	Type type;
	switch(s->entryType){
		case ENTRY_CONSTANT:	type = s->u.eConstant.type;		break;
		case ENTRY_VARIABLE:	type = s->u.eVariable.type;		break;
		case ENTRY_PARAMETER:	type = s->u.eParameter.type;	break;
		case ENTRY_TEMPORARY:	type = s->u.eTemporary.type;	break;
		default:				internal("final: typeSize(): unhandled case");
	}
	if(o->type==OPERAND_DEREFERENCE)	return sizeOfType(type->refType);
	else if (o->type==OPERAND_SYMBOL)	return sizeOfType(type);
}

//return the size of the element of an array (array is given as an Operand)
int refTypeSize(Operand o)
{
	if(o->type!=OPERAND_SYMBOL) internal("final: refTypeSize() operand in call must be an OPERAND_SYMBOL Operand"); 
	SymbolEntry * s = o->u.symbol;
	Type type;
	switch(s->entryType){
		case ENTRY_VARIABLE:	type = s->u.eVariable.type;		break;
		case ENTRY_PARAMETER:	type = s->u.eParameter.type;	break;
		case ENTRY_TEMPORARY:	type = s->u.eTemporary.type;	break;
		default:				internal("final: refTypetSize(): unhandled case");
	}
	if(!equalType(type,typeIArray(typeAny))) internal("final: refTypeSize() type of Operand is not an array");
	return sizeOfType(type->refType);
}


