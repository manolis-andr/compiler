.PHONY: clean distclean

#User-defined flags, that must be given as a command line argument
UFLAGS=

CC=gcc
CFLAGS= $(UFLAGS)

DEBUG?=0
ifeq ($(DEBUG),1)
	CFLAGS+= -g -DDEBUG
endif

INTERMEDIATE?=0
ifeq ($(INTERMEDIATE),1)
	CFLAGS+= -DINTERMEDIATE
endif

OBJS= parser.o lexer.o symbol.o general.o error.o intermediate.o

ifeq ($(INTERMEDIATE),0)
	OBJS+= final.o
endif

compiler: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ -lfl

parser.c: parser.y
	bison -dv -o $@ $<

lexer.c: lexer.l parser.h
	flex -s -o $@ $<

symbol.o: symbol.c error.o general.o
	$(CC) $(CFLAGS) -c -o $@ $<

intermediate.o: intermediate.c error.o general.o 
	$(CC) $(CFLAGS) -c -o $@ $<

final.o: final.c error.o general.o
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean: 
	$(RM) lexer.c parser.c *.o *~

distclean:
	$(RM) lexer.c parser.c parser.output *.o *.asm *.imm *~ compiler 
