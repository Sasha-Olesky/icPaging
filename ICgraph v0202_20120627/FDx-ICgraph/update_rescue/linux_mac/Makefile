load: main.o xmodem.o sdb.o
	cc -o $@ $^

main.o: main.c main.h xmodem.h sdb.h
	cc -c -o $@ $<

xmodem.o: xmodem.c main.h xmodem.h
	cc -c -o $@ $<

sdb.o: sdb.c main.h
	cc -c -o $@ $<
