# LolVM, and the Lol language

This is a language and runtime I'm making to get experience with writing
compiled, statically typed, low-level languages.
All my previous languages have been dynamically typed high level ones.

Here's some example code:

```
struct IntPair {
	int a;
	int b;
}

void main() {
	mypair = uninitialized IntPair;
	mypair's b = 33;
	dbg-print mypair's b;

	mypair's a = 0;
	lim = 10;
	while mypair's a < lim {
		dbg-print mypair's a;
		mypair's a = mypair's a + 1;
	}
}
```

The language currently uses `'s` as a struct accessor token.
I ... don't know if that's a good idea.

## The compiler

The compiler for the Lol language is written in Raku.
I chose Raku because I didn't want to spend time writing a parser
(I've done that already and it takes a while)
and Raku's [grammar](https://docs.raku.org/language/grammars) system is fantastic.

Raku is bonkers and I rather like it.
I'll probably use it again for all sorts of compilers and assemblers and interpreters 
in the future

The source code is in [lol.raku](lol.raku).

## The VM

The VM, called LolVM, is written in C.
It has an instruction set that's pretty similar to assembly language,
and I plan to eventually write a converter from LolVM bytecode
to RISC-V, ARM and/or x86 assembly in the future.

The source code is in [lolvm.c](lolvm.c).
The code isn't great at the moment, with a lot of hard-coded sizes
and the program will segfault if anything goes wrong.
Making the VM robust isn't currently a focus.
