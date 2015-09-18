.PHONY: clean distclean

#User-defined flags, that must be given as a command line argument
UFLAGS=

CC=gcc
CFLAGS= -g $(UFLAGS)

DEBUG?=1
ifeq ($(DEBUG),1)
	CFLAGS+= -DDEBUG
endif

parser: parser.o lexer.o symbol.o general.o error.o
	$(CC) $(CFLAGS) -o $@ $^ -lfl

parser.c: parser.y
	bison -dv -o $@ $<

lexer.c: lexer.l parser.h
	flex -s -o $@ $<

#lexer.o: lexer.c
#	$(CC) $(CFLAGS) -c -o $@ $<

#pareser.o: parser.c
#	$(CC) $(CFLAGS) -c -o $@ $<

symbol.o: symbol.c error.o general.o
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean: 
	$(RM) lexer.c parser.c *.o *~

distclean:
	$(RM) *.c *.o *~ parser
