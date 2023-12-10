CFLAGS = -g

lolvm: lolvm.c
	$(CC) $(CFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -f lolvm
