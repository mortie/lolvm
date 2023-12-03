CFLAGS = -g

lolvm: lolvm.c

.PHONY: clean
clean:
	rm -f lolvm
