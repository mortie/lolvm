#!/usr/bin/env raku

grammar Lol {
	rule TOP {
		^ <toplevel>* $
	}

	rule toplevel {
		| <struct-decl>
		| <func-decl>
	}

	rule struct-decl {
		'struct' <identifier> '{' <struct-fields> '}'
	}

	rule struct-fields {
		<struct-field>* %% ';'
	}

	rule struct-field {
		<type> <identifier>
	}

	rule func-decl {
		<type> <identifier> '(' <formal-params> ')' <block>
	}

	rule formal-params {
		(<type> <identifier>)* %% ','
	}

	rule block {
		'{' <statement>* %% ';' '}'
	}

	rule statement {
		| <block>
		| <if-statm>
		| <dbg-print-statm>
		| <assign-statm>
		| <expression>
	}

	rule if-statm {
		'if' <expression> <statement> ('else' <statement>)?
	}

	rule dbg-print-statm {
		'dbg-print' <expression>
	}

	rule assign-statm {
		<identifier> '=' <expression>
	}

	rule expression {
		| <num-literal>
		| <group-expression>
		| <func-call>
		| <identifier>
	}

	rule group-expression {
		'(' <expression> ')'
	}

	rule type {
		<identifier> ('[' <type>+ %% ',' ']')?
	}

	token identifier {
		<:alpha>+
	}

	token num-literal {
		\d+ ('.' \d+)?
	}

	rule func-call {
		<identifier> '(' <expression>* %% ',' ')'
	}
}

enum LolOp <
	SETI_32
	SETI_64
	ADD_32
	ADD_64
	ADDI_32
	ADDI_64
	BEGIN_FRAME
	END_FRAME
	CALL
	RETURN
	DBG_PRINT_I32
	DBG_PRINT_I64
	HALT
>;

class Type {
	has Int $.size;
	has Str $.desc;
}

class PrimitiveType is Type {
}

class StructType is Type {
	has %.fields;
}

class FuncDecl {
	has $.return-type;
	has @.params;
	has $.body;

	has Int $.offset is rw;
}

my %builtin-types = %(
	void => PrimitiveType.new(size => 0, desc => "void"),
	int => PrimitiveType.new(size => 4, desc => "int"),
	long => PrimitiveType.new(size => 8, desc => "long"),
);

class LocalVar {
	has Int $.index;
	has Type $.type;
	has Bool $.temp;
}

class StackFrame {
	has LocalVar %.vars is rw;
	has LocalVar @.temps is rw;
	has Int $.idx is rw = 0;
	has Int $.max-idx is rw = 0;

	method has(Str $name) {
		%.vars{$name}:exists;
	}

	method get(Str $name)  {
		if not %.vars{$name}:exists {
			die "Variable doesn't exist: $name";
		}

		%.vars{$name};
	}

	method define(Str $name, Type $type) {
		if %.vars{$name}:exists {
			die "Variable already exists: $name";
		}

		my $var = LocalVar.new(
			index => $.idx,
			type => $type,
			temp => False,
		);
		%.vars{$name} = $var;
		$.idx += $type.size;
		$.max-idx += $type.size;
		$var;
	}

	method push-temp($type) {
		my $var = LocalVar.new(
			index => $.idx,
			type => $type,
			temp => True,
		);
		$.idx += $type.size;
		if $.idx > $.max-idx {
			$.max-idx = $.idx;
		}
		@.temps.append($var);
		$var;
	}

	method pop-if-temp($var) {
		if $var.temp {
			my $popped-var = @.temps.pop();
			if not ($var === $popped-var) {
				die "Popped non-top-of-stack variable at index {$var.index} " ~
					"(top has index {$popped-var.index}";
			}

			$.idx -= $var.type.size;
		}
	}
}

class ExprResult {
	has Buf $.code is rw;
	has LocalVar $.var;
}

class Program {
	has Type %.types;
	has FuncDecl %.funcs;

	method register-defaults() {
		for %builtin-types.kv -> $k, $v {
			%.types{$k} = $v;
		}
	}

	method lookup-type-from-cst($type-cst) returns Type {
		my $name = $type-cst<identifier>.Str;
		if not %.types{$name}:exists {
			die "Unknown type: $name";
		}

		$.types{$name};
	}

	method analyze-struct-decl($struct-decl) {
		my $name = $struct-decl<identifier>.Str;
		if $.types<$name>:exists {
			die "A type named $name already exists!";
		}

		my %fields;
		my $size = 0;
		for $struct-decl<struct-fields><struct-field> -> $struct-field-cst {
			my $field-type = $.lookup-type-from-cst($struct-field-cst<type>);
			my $field-name = $struct-field-cst<identifier>.Str;

			if %fields{$field-name}:exists {
				die "Duplicate field name: $field-name";
			}

			%fields{$field-name} = $field-type;
			$size += $field-type.size;
		}

		%.types{$name} = StructType.new(
			fields => %fields,
			size => $size,
			desc => "struct $name",
		);
	}

	method analyze-func-decl($func-decl) {
		my $name = $func-decl<identifier>.Str;
		if $.funcs<$name>:exists {
			die "A function named $name already exists!";
		}

		my $return-type = $.lookup-type-from-cst($func-decl<type>);

		my @params;
		for $func-decl<formal-params>[0] -> $formal-param-cst {
			@params.push($.lookup-type-from-cst($formal-param-cst<type>));
		}

		%.funcs{$name} = FuncDecl.new(
			name => $name,
			return-type => $return-type,
			params => @params,
			body => $func-decl<block>,
		);
	}

	method analyze($cst) {
		for $cst<toplevel> -> $toplevel {
			if $toplevel<struct-decl> {
				$.analyze-struct-decl($toplevel<struct-decl>);
			} elsif $toplevel<func-decl> {
				$.analyze-func-decl($toplevel<func-decl>);
			} else {
				die "Bad toplevel";
			}
		}
	}

	method find-expression-type($frame, $expr) returns Type {
		if $expr<num-literal>:exists {
			%builtin-types<int>;
		} elsif $expr<group-expression>:exists {
			$.find-expression-type($expr<group-expression><expression>);
		} elsif $expr<func-call>:exists {
			my $name = $expr<func-call><identifier>.Str;
			if not %.funcs{$name}:exists {
				die "Unknown function: $name"
			}

			my $func = %.funcs{$name};
			$func.return-type;
		} elsif $expr<identifier>:exists {
			my $name = $expr<identifier>.Str;
			$frame.get($name).type;
		} else {
			die "Bad expression";
		}
	}

	method populate-stack-frame($frame, @statms) {
		for @statms -> $statm {
			if $statm<block>:exists {
				$.populate-stack-frame($frame, $statm<block>)
			} elsif $statm<assign-statm>:exists {
				my $name = $statm<assign-statm><identifier>.Str;
				my $expr = $statm<assign-statm><expression>;
				my $type = $.find-expression-type($frame, $expr);

				if $frame.has($name) {
					my $existing = $frame.get($name);
					if not ($existing.type === $type) {
						die "Variable '$name' redeclared as '{$type.desc}' " ~
							"(was '{$existing.type.desc}')";
					}
				} else {
					$frame.define($name, $type);
				}
			}
		}
	}

	method compile-expr($frame, $expr) returns ExprResult {
		if $expr<num-literal> {
			my $temp = $frame.push-temp(%builtin-types<int>);
			my $code = Buf.new(
				LolOp::SETI_32.Int, $temp.index, 0, +$expr<num-literal>.Str, 0, 0, 0);
			ExprResult.new(code => $code, var => $temp);
		} else {
			die "Bad expr";
		}
	}

	method compile-statm($frame, $statm) returns Buf {
		if $statm<block>:exists {
			$.compile-block($frame, $statm<block>);
		} elsif $statm<dbg-print-statm>:exists {
			my $res = $.compile-expr($frame, $statm<dbg-print-statm><expression>);
			$res.code.append(LolOp::DBG_PRINT_I32, $res.var.index, 0);
			$frame.pop-if-temp($res.var);
			$res.code;
		} else {
			die "Bad statm";
		}
	}

	method compile-block($frame, $block) returns Buf {
		my $code = Buf.new();
		for $block<statement> -> $statm {
			$code.append($.compile-statm($frame, $statm));
		}
		$code;
	}

	method compile-function($name, $func) returns Buf {
		my $frame = StackFrame.new();
		$.populate-stack-frame($frame, $func.body<statement>);
		my $code = $.compile-block($frame, $func.body);
		$code.prepend(LolOp::BEGIN_FRAME.Int, $frame.max-idx, 0);
		$code.append(LolOp::RETURN.Int);
		$code;
	}

	method compile-functions() returns Buf {
		my $code = Buf.new(LolOp::CALL.Int, 0, 0, 0, 0, LolOp::HALT.Int);

		if not %.funcs<main>:exists {
			die "Missing main function";
		}

		my $main-func = %.funcs<main>;
		if not ($main-func.return-type === %builtin-types<void>) {
			die "Function main must have return type void";
		} elsif +$main-func.params != 0 {
			die "Function main must have no parameters";
		}

		for %.funcs.kv -> $name, $func {
			say "compiling function $name";
			$func.offset = +$code;
			$code.append($.compile-function($name, $func));
		}

		$code[1] = $main-func.offset;
		$code;
	}
}

my $cst = Lol.parsefile('test.lol');

my $prog = Program.new();
$prog.register-defaults();
$prog.analyze($cst);
my $code = $prog.compile-functions();

my $out = open "test.blol", :w, :bin;
$out.write($code);
$out.close();
