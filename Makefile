CFLAGS = -g

lolvm: lolvm.c instructions.x.h
	$(CC) $(CFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -f lolvm
