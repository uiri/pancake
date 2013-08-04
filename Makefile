CC=gcc
CFLAGS=-Wall -g -pedantic -o

all:	pancake.l.c pancake.y.c mylist.o
	$(CC) $(CFLAGS) pancake mylist.o pancake.l.c pancake.y.c

pancake.l.c: pancake.l
	flex -o pancake.l.c pancake.l

pancake.y.c: pancake.y
	bison -d -o pancake.y.c pancake.y

mylist.o: mylist.c mylist.h
	$(CC) $(CFLAGS) mylist.o -c mylist.c

clean:
	rm mylist.o
	rm pancake.y.c
	rm pancake.y.h
	rm pancake.l.c
	rm pancake
