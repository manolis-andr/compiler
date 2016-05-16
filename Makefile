.PHONY: clean 

#User-defined flags, that must be given as a command line argument
FLAGS=

## Flags that can be used:
#	- DGC_FREE: ti define GC_FREE and avoid using garbage collector (no arrays and lists allowed then)

CC=gcc 
CFLAGS= $(FLAGS)

DEBUG?=0
ifeq ($(DEBUG),1)
	CFLAGS+= -g -DDEBUG
endif

INTERMEDIATE?=0
ifeq ($(INTERMEDIATE),1)
	CFLAGS+= -DINTERMEDIATE
endif

OBJS= parser.o lexer.o symbol.o general.o error.o intermediate.o datastructs.o

ifeq ($(INTERMEDIATE),0)
	OBJS+= final.o
endif

# general dependencies
DEPS= general.h error.h

###### Rules ######

compiler: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ -lfl

parser.c: parser.y
	bison -dv -o $@ $<

lexer.c: lexer.l parser.h
	flex -s -o $@ $<

lexer.o: lexer.c $(DEPS) symbol.h intermediate.h
	$(CC) $(CFLAGS) -o $@ -c $<

parser.o: parser.c $(DEPS) datastructs.h symbol.h intermediate.h final.h
	$(CC) $(CFLAGS) -o $@ -c $<

intermediate.o: intermediate.c $(DEPS) symbol.h intermediate.h
	$(CC) $(CFLAGS) -o $@ -c $<

final.o: final.c $(DEPS) symbol.h datastructs.h intermediate.h final.h
	$(CC) $(CFLAGS) -o $@ -c $<

%.o: %.c %.h $(DEPS)
	$(CC) $(CFLAGS) -o $@ -c $<


### Header file dependencies (from includes)
#1. error.o:	general.h error.h
#2. general.o:	general.h error.h
#4. lexer.o:	general.h error.h symbol.h intermediate.h
#5. parser.o:	general.h error.h symbol.h intermediate.h final.h datastructs.h
#6. symbol.o:	general.h error.h symbol.h
#7. interme.o:	general.h error.h symbol.h intermediate.h
#8. final.o:	general.h error.h symbol.h intermediate.h final.h datastructs.h


clean:
	$(RM) lexer.c parser.c parser.output *.o *~ compiler 
