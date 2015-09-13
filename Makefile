.PHONY: clean distclean

W=

CC=gcc
CFLAGS= -g $W

parser: parser.o lexer.o
	$(CC) $(CFLAGS) -o $@ $^ -lfl

parser.c: parser.y
	bison -dv -o $@ $<

lexer.c: lexer.l
	flex -s -o $@ $<

lexer.o: lexer.c parser.h
	$(CC) $(CFLAGS) -c -o $@ $<

pareser.o: parser.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean: 
	$(RM) *.c *.o *~

distclean:
	$(RM) *.c *.o *~ parser
