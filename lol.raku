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
		| <while-statm>
		| <dbg-print-statm>
		| <return-statm>
		| <assign-statm>
		| <expression>
	}

	rule if-statm {
		'if' <expression> <statement> ('else' <statement>)?
	}

	rule while-statm {
		'while' <expression> <statement>
	}

	rule dbg-print-statm {
		'dbg-print' <expression>
	}

	rule return-statm {
		'return' <expression>
	}

	rule assign-statm {
		<identifier> '=' <expression>
	}

	rule expression {
		| <bin-op>
		| <expression-part>
	}

	rule bin-op {
		<expression-part> <bin-operator> <expression>
	}

	token bin-operator {
		'+' | '==' | "!=" | "<" | "<=" | ">" | ">="
	}

	rule expression-part {
		| <uninitialized>
		| <num-literal>
		| <bool-literal>
		| <group-expression>
		| <func-call>
		| <locator>
	}

	rule uninitialized {
		'uninitialized' <type>
	}

	rule group-expression {
		'(' <expression> ')'
	}

	rule func-call {
		<identifier> '(' <expression>* %% ',' ')'
	}

	rule locator {
		<identifier> ("'s" <locator>)?
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

	token bool-literal {
		true | false
	}
}

enum LolOp <
	SETI_8
	SETI_32
	SETI_64
	COPY_32
	COPY_64
	COPY_N
	ADD_32
	ADD_64
	ADDI_32
	ADDI_64
	EQ_8
	EQ_32
	EQ_64
	NEQ_8
	NEQ_32
	NEQ_64
	LT_U8
	LT_I32
	LT_I64
	LE_U8
	LE_I32
	LE_I64

	CALL
	RETURN
	BRANCH
	BRANCH_Z
	BRANCH_NZ
	DBG_PRINT_U8
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

class StructField {
	has Int $.offset;
	has Type $.type;
}

class StructType is Type {
	has StructField %.fields;
}

class FuncParam {
	has Type $.type;
	has Str $.name;
}

class LocalVar {
	has Int $.index;
	has Type $.type;
	has Bool $.temp;
}

class FuncDecl {
	has Str $.name;
	has LocalVar $.return-var;
	has FuncParam @.params;
	has $.body;

	has Int $.offset is rw = Nil;
}

my %builtin-types = %(
	void => PrimitiveType.new(size => 0, desc => "void"),
	bool => PrimitiveType.new(size => 1, desc => "bool"),
	int => PrimitiveType.new(size => 4, desc => "int"),
	long => PrimitiveType.new(size => 8, desc => "long"),
);

class StackFrame {
	has FuncDecl $.func;
	has LocalVar %.vars is rw;
	has LocalVar @.temps is rw;
	has Int $.idx is rw = 0;
	has Int $.max-size is rw = 0;

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
		$.max-size += $type.size;
		$var;
	}

	method push-temp($type) {
		my $var = LocalVar.new(
			index => $.idx,
			type => $type,
			temp => True,
		);
		$.idx += $type.size;
		if $.idx > $.max-size {
			$.max-size = $.idx;
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

sub append-i16le(Buf $buf, int16 $value) {
	$buf.write-int16(+$buf, $value, LittleEndian);
}

sub append-u32le(Buf $buf, uint32 $value) {
	$buf.write-uint32(+$buf, $value, LittleEndian);
}

sub append-i32le(Buf $buf, int32 $value) {
	$buf.write-int32(+$buf, $value, LittleEndian);
}

class FuncCallFixup {
	has uint32 $.location;
	has Str $.name;
};

class Program {
	has Type %.types;
	has FuncDecl @.funcs;
	has FuncDecl %.funcs-map;

	has FuncCallFixup @.func-call-fixups;

	method register-defaults() {
		for %builtin-types.kv -> $k, $v {
			%.types{$k} = $v;
		}
	}

	method type-from-cst($type-cst) returns Type {
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
			my $field-type = $.type-from-cst($struct-field-cst<type>);
			my $field-name = $struct-field-cst<identifier>.Str;

			if %fields{$field-name}:exists {
				die "Duplicate field name: $field-name";
			}

			%fields{$field-name} = StructField.new(
				offset => $size,
				type => $field-type,
			);
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

		my $return-type = $.type-from-cst($func-decl<type>);
		my $return-index = -$return-type.size;

		my @params;
		for $func-decl<formal-params>[0] -> $formal-param-cst {
			my $type = $.type-from-cst($formal-param-cst<type>);
			$return-index -= $type.size;
			@params.push(FuncParam.new(
				type => $type,
				name => $formal-param-cst<identifier>.Str,
			));
		}

		my $func = FuncDecl.new(
			name => $name,
			return-var => LocalVar.new(
				index => $return-index,
				type => $return-type,
				temp => False,
			),
			params => @params,
			body => $func-decl<block>,
		);
		@.funcs.append($func);
		%.funcs-map{$name} = $func;
	}

	method analyze($cst) {
		for $cst<toplevel> -> $toplevel {
			if $toplevel<struct-decl> {
				$.analyze-struct-decl($toplevel<struct-decl>);
			} elsif $toplevel<func-decl> {
				$.analyze-func-decl($toplevel<func-decl>);
			} else {
				die "Bad toplevel $toplevel";
			}
		}
	}

	method reconcile-types(Type $lhs, Type $rhs) returns Type {
		if not ($lhs === $rhs) {
			die "Incompatible types: {$lhs.desc}, {$rhs.desc}"
		}

		$lhs;
	}

	method find-expression-part-type($frame, $part) returns Type {
		if $part<uninitialized>:exists {
			$.type-from-cst($part<uninitialized><type>);
		} elsif $part<num-literal>:exists {
			%builtin-types<int>;
		} elsif $part<bool-literal>:exists {
			%builtin-types<bool>;
		} elsif $part<group-expression>:exists {
			$.find-expression-type($part<group-expression><expression>);
		} elsif $part<func-call>:exists {
			my $name = $part<func-call><identifier>.Str;
			if not %.funcs{$name}:exists {
				die "Unknown function: $name"
			}

			my $func = %.funcs{$name};
			$func.return-var.type;
		} elsif $part<locator>:exists {
			my $locator = $part<locator>;
			my $type = $frame.get($locator<identifier>.Str).type;

			while $locator[0] {
				$locator = $locator[0]<locator>;

				if not $type.isa(StructType) {
					die "Used accessor on non-struct type '{$type.desc}'";
				}

				my $name = $locator<identifier>.Str;
				if not $type.fields{$name} {
					die "Type '{$type.desc}' has no member '$name'";
				}

				$type = $type.fields{$name}.type;
			}

			$type;
		} else {
			die "Bad expression '$part'";
		}
	}

	method find-expression-type($frame, $expr) returns Type {
		if $expr<bin-op>:exists {
			my $operator = $expr<bin-op><bin-operator>.Str;
			if $operator eq any("==", "!=", "<", "<=", ">", ">=") {
				%builtin-types<bool>;
			} else {
				$.reconcile-types(
					$.find-expression-part-type($frame, $expr<bin-op><expression-part>),
					$.find-expression-type($frame, $expr<bin-op><expression>));
			}
		} elsif $expr<expression-part>:exists {
			$.find-expression-part-type($frame, $expr<expression-part>);
		} else {
			die "Bad expression '$expr'";
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

	method compile-expr-part($frame, $part, Buf $out) returns LocalVar {
		if $part<uninitialized> {
			$frame.push-temp($.type-from-cst($part<uninitialized><type>));
		} elsif $part<num-literal> {
			my $temp = $frame.push-temp(%builtin-types<int>);
			$out.append(LolOp::SETI_32);
			append-i16le($out, $temp.index);
			append-i32le($out, +$part<num-literal>.Str);
			$temp;
		} elsif $part<bool-literal> {
			my $temp = $frame.push-temp(%builtin-types<bool>);
			$out.append(LolOp::SETI_8);
			append-i16le($out, $temp.index);
			if $part<bool-literal>.Str eq "true" {
				$out.append(1);
			} elsif $part<bool-literal>.Str eq "false" {
				$out.append(0);
			} else {
				die "Bad bool '{$part<bool-literal>}'";
			}
			$temp;
		} elsif $part<group-expression> {
			$.compile-expr($frame, $part<group-expression><expression>, $out);
		} elsif $part<func-call> {
			my $name = $part<func-call><identifier>.Str;
			if not %.funcs-map{$name}:exists {
				die "Call to undefined function '$name'";
			}

			my $func = %.funcs-map{$name};
			if +$func.params != +$part<func-call><expression> {
				die "Function call with invalid number of arguments";
			}

			my $return-val = $frame.push-temp($func.return-var.type);
			my @param-vars;
			for 0..^+$func.params -> $i {
				my $param = $func.params[$i];
				my $expr = $part<func-call><expression>[$i];
				my $var = $.compile-expr($frame, $expr, $out);
				if not ($var.type === $param.type) {
					die "Function call with invalid parameter type";
				}

				if $var.temp {
					@param-vars.append($var);
				} else {
					my $v = $frame.push-temp($var.type);
					$.generate-copy($v.index, $var.index, $var.type.size, $out);
					@param-vars.append($v);
					$frame.pop-if-temp($v);
				}
			}

			$out.append(LolOp::CALL);

			append-i16le($out, $frame.idx);

			if $func.offset.defined {
				append-u32le($out, $func.offset);
			} else {
				$.func-call-fixups.append(FuncCallFixup.new(
					location => +$out,
					name => $name,
				));
				append-u32le($out, 0);
			}

			while @param-vars {
				my $var = @param-vars.pop();
				$frame.pop-if-temp($var);
			}

			$return-val;
		} elsif $part<locator> {
			my $locator = $part<locator>;
			my $var = $frame.get($locator<identifier>.Str);
			my $type = $var.type;
			my $offset = 0;

			while $locator[0] {
				$locator = $locator[0]<locator>;

				if not $type.isa(StructType) {
					die "Used accessor on non-struct type '{$type.desc}'";
				}

				my $name = $locator<identifier>.Str;
				if not $type.fields{$name} {
					die "Type '{$type.desc}' has no member '$name'";
				}

				my $field = $type.fields{$name};
				$offset += $field.offset;
				$type = $field.type;
			}

			LocalVar.new(
				index => $var.index + $offset,
				type => $type,
				temp => False,
			)
		} else {
			die "Bad expression '$part'";
		}
	}

	method compile-expr-part-to-loc($frame, LocalVar $dest, $part, Buf $out) {
		if $part<uninitialized> {
			my $type = $.type-from-cst($part<uninitialized><type>);
			$.reconcile-types($dest.type, $type);
		} elsif $part<num-literal> {
			if not ($dest.type === %builtin-types<int>) {
				die "Invalid destination type for number literal";
			}

			$out.append(LolOp::SETI_32);
			append-i16le($out, $dest.index);
			append-i32le($out, +$part<num-literal>.Str);
		} elsif $part<bool-literal> {
			if not ($dest.type === %builtin-types<bool>) {
				die "Invalid destination type for bool";
			}

			$out.append(LolOp::SETI_8);
			append-i16le($out, $dest.index);
			if $part<bool-literal>.Str eq "true" {
				$out.append(1);
			} elsif $part<bool-literal>.Str eq "false" {
				$out.append(0);
			} else {
				die "Bad bool '{$part<bool-literal>}'";
			}
		} else {
			my $src = $.compile-expr-part($frame, $part, $out);
			my $type = $.reconcile-types($dest.type, $src.type);
			$.generate-copy($dest.index, $src.index, $type.size, $out);
			$frame.pop-if-temp($src);
		}
	}

	method compile-expr($frame, $expr, Buf $out) returns LocalVar {
		if $expr<bin-op> {
			my $operator = $expr<bin-op><bin-operator>.Str;
			my $lhs = $expr<bin-op><expression-part>;
			my $rhs = $expr<bin-op><expression>;
			my $type;
			if $operator eq any("==", "!=", "<", "<=", ">", ">=") {
				$type = %builtin-types<bool>;
			} else {
				$type = $.reconcile-types(
					$.find-expression-part-type($frame, $lhs),
					$.find-expression-type($frame, $rhs));
			}
			my $temp = $frame.push-temp($type);
			$.compile-expr-to-loc($frame, $temp, $expr, $out);
			$temp;
		} elsif $expr<expression-part> {
			$.compile-expr-part($frame, $expr<expression-part>, $out);
		} else {
			die "Bad expression '$expr'";
		}
	}

	method compile-expr-to-loc($frame, LocalVar $dest, $expr, Buf $out) {
		if $expr<bin-op> {
			my $lhs = $expr<bin-op><expression-part>;
			my $rhs = $expr<bin-op><expression>;
			my $operator = $expr<bin-op><bin-operator>.Str;

			my $lhs-var = $.compile-expr-part($frame, $lhs, $out);
			my $rhs-var = $.compile-expr($frame, $rhs, $out);

			my $src-type = $.reconcile-types($lhs-var.type, $rhs-var.type);
			my $swap-opers = False;

			if $dest.type === %builtin-types<bool> and $src-type === %builtin-types<bool> {
				if $operator eq "==" {
					$out.append(LolOp::EQ_8);
				} elsif $operator eq "!=" {
					$out.append(LolOp::NEQ_8);
				} else {
					die "Bad operator: '$operator'";
				}
			} elsif $dest.type === %builtin-types<bool> and $src-type === %builtin-types<int> {
				if $operator eq "==" {
					$out.append(LolOp::EQ_32);
				} elsif $operator eq "!=" {
					$out.append(LolOp::NEQ_32);
				} elsif $operator eq "<" {
					$out.append(LolOp::LT_I32);
				} elsif $operator eq "<=" {
					$out.append(LolOp::LE_I32);
				} elsif $operator eq ">" {
					$out.append(LolOp::LT_I32);
					$swap-opers = True;
				} elsif $operator eq ">=" {
					$out.append(LolOp::LE_I32);
					$swap-opers = True;
				} else {
					die "Bad operator: '$operator'";
				}
			} elsif $dest.type === %builtin-types<bool> and $src-type === %builtin-types<long> {
				if $operator eq "==" {
					$out.append(LolOp::EQ_64);
				} elsif $operator eq "!=" {
					$out.append(LolOp::NEQ_64);
				} elsif $operator eq "<" {
					$out.append(LolOp::LT_I64);
				} elsif $operator eq "<=" {
					$out.append(LolOp::LE_I64);
				} elsif $operator eq ">" {
					$out.append(LolOp::LT_I64);
					$swap-opers = True;
				} elsif $operator eq ">=" {
					$out.append(LolOp::LE_I64);
					$swap-opers = True;
				} else {
					die "Bad operator: '$operator'";
				}
			} elsif $dest.type === %builtin-types<int> and $src-type === %builtin-types<int> {
				if $operator eq "+" {
					$out.append(LolOp::ADD_32);
				} else {
					die "Bad operator: '$operator'";
				}
			} elsif $dest.type === %builtin-types<long> and $src-type === %builtin-types<long> {
				if $operator eq "+" {
					$out.append(LolOp::ADD_64);
				} else {
					die "Bad operator: '$operator'";
				}
			} else {
				die "Bad type: '{$dest.type.desc}'";
			}

			append-i16le($out, $dest.index);
			if $swap-opers {
				append-i16le($out, $rhs-var.index);
				append-i16le($out, $lhs-var.index);
			} else {
				append-i16le($out, $lhs-var.index);
				append-i16le($out, $rhs-var.index);
			}

			$frame.pop-if-temp($rhs-var);
			$frame.pop-if-temp($lhs-var);
		} elsif $expr<expression-part> {
			$.compile-expr-part-to-loc($frame, $dest, $expr<expression-part>, $out);
		} else {
			my $src = $.compile-expr($frame, $expr, $out);
			my $type = $.reconcile-types($dest.type, $src.type);
			$.generate-copy($dest.index, $src.index, $type.size, $out);
			$frame.pop-if-temp($src);
		}
	}

	method generate-copy(Int $dest, Int $src, Int $size, Buf $out) {
		if $size == 4 {
			$out.append(LolOp::COPY_32);
			append-i16le($out, $dest);
			append-i16le($out, $src);
		} elsif $size == 8 {
			$out.append(LolOp::COPY_64);
			append-i16le($out, $dest);
			append-i16le($out, $src);
		} else {
			$out.append(LolOp::COPY_N);
			append-i16le($out, $dest);
			append-i16le($out, $src);
			append-u32le($out, $size);
		}
	}

	method compile-statm($frame, $statm, Buf $out) {
		if $statm<block> {
			$.compile-block($frame, $statm<block>, $out);
		} elsif $statm<dbg-print-statm> {
			my $var = $.compile-expr($frame, $statm<dbg-print-statm><expression>, $out);
			if $var.type === %builtin-types<bool> {
				$out.append(LolOp::DBG_PRINT_U8);
			} elsif $var.type === %builtin-types<int> {
				$out.append(LolOp::DBG_PRINT_I32);
			} elsif $var.type === %builtin-types<long> {
				$out.append(LolOp::DBG_PRINT_I64);
			} else {
				die "Type incompatible with dbg-print: '{$var.type.desc}'";
			}

			append-i16le($out, $var.index);
			$frame.pop-if-temp($var);
		} elsif $statm<if-statm> {
			my $cond-var = $.compile-expr($frame, $statm<if-statm><expression>, $out);
			my $if-start-idx = +$out;
			$out.append(LolOp::BRANCH_Z);
			append-i16le($out, $cond-var.index);
			my $fixup-skip-if-body-idx = +$out;
			$out.append(0, 0);
			$frame.pop-if-temp($cond-var);

			$.compile-statm($frame, $statm<if-statm><statement>, $out);

			if $statm<if-statm>[0] {
				my $else-start-idx = +$out;
				$out.append(LolOp::BRANCH);
				my $fixup-skip-else-body-idx = +$out;
				$out.append(0, 0);

				$out.write-int16($fixup-skip-if-body-idx, +$out - $if-start-idx, LittleEndian);

				$.compile-statm($frame, $statm<if-statm>[0]<statement>, $out);
				$out.write-int16($fixup-skip-else-body-idx, +$out - $else-start-idx, LittleEndian);
			} else {
				$out.write-int16($fixup-skip-if-body-idx, +$out - $if-start-idx, LittleEndian);
			}
		} elsif $statm<while-statm> {
			say "whlie statm at {+$out}";
			my $while-start-idx = +$out;
			my $cond-var = $.compile-expr($frame, $statm<while-statm><expression>, $out);
			my $skip-body-branch-idx = +$out;
			$out.append(LolOp::BRANCH_Z);
			append-i16le($out, $cond-var.index);
			my $fixup-skip-body-idx = +$out;
			append-i16le($out, 0);
			$frame.pop-if-temp($cond-var);

			$.compile-statm($frame, $statm<while-statm><statement>, $out);

			my $jump-back-delta = $while-start-idx - +$out;
			$out.append(LolOp::BRANCH);
			append-i16le($out, $jump-back-delta);

			say "whlie statm done at {+$out}";
			$out.write-int16($fixup-skip-body-idx, +$out - $skip-body-branch-idx, LittleEndian);
		} elsif $statm<return-statm> {
			$.compile-expr-to-loc(
				$frame, $frame.func.return-var, $statm<return-statm><expression>, $out);
		} elsif $statm<assign-statm> {
			my $name = $statm<assign-statm><identifier>.Str;
			my $dest-var = $frame.get($name);
			my $expr = $statm<assign-statm><expression>;
			$.compile-expr-to-loc($frame, $dest-var, $expr, $out);
		} elsif $statm<expression> {
			my $var = $.compile-expr($frame, $statm<expression>, $out);
			$frame.pop-if-temp($var);
		} else {
			die "Bad statement '$statm'";
		}
	}

	method compile-block($frame, $block, Buf $out) {
		for $block<statement> -> $statm {
			$.compile-statm($frame, $statm, $out);
		}
	}

	method compile-function($func, Buf $out) {
		my $frame = StackFrame.new(func => $func);

		my $params-index = 0;
		for $func.params -> $param {
			$params-index -= $param.type.size;
		}

		for $func.params -> $param {
			$frame.vars{$param.name} = LocalVar.new(
				index => $params-index,
				type => $param.type,
				temp => False,
			);
			$params-index += $param.type.size;
		}

		$.populate-stack-frame($frame, $func.body<statement>);
		$.compile-block($frame, $func.body, $out);

		$out.append(LolOp::RETURN);
	}

	method compile-functions(Buf $out) {
		if not %.funcs-map<main>:exists {
			die "Missing main function";
		}

		my $main-func = %.funcs-map<main>;
		if not ($main-func.return-var.type === %builtin-types<void>) {
			die "Function main must have return type void";
		} elsif +$main-func.params != 0 {
			die "Function main must have no parameters";
		}

		$out.append(LolOp::CALL, 0, 0);
		my $main-offset-fixup-idx = +$out;
		$out.append(0, 0, 0, 0, LolOp::HALT);

		for @.funcs -> $func {
			$func.offset = +$out;
			say "  Compiling function {$func.name} @ {$func.offset}...";
			$.compile-function($func, $out);
		}

		$out.write-uint32($main-offset-fixup-idx, $main-func.offset, LittleEndian);

		for @.func-call-fixups -> $fixup {
			my $func = $.funcs-map{$fixup.name};
			$out.write-uint32($fixup.location, $func.offset, LittleEndian);
		}
	}
}

say "Compiling: test.lol -> test.blol";
my $cst = Lol.parsefile('test.lol');
if not $cst.defined {
	die "Parse error!";
}

my $prog = Program.new();
$prog.register-defaults();
$prog.analyze($cst);
my $out = Buf.new();
$prog.compile-functions($out);

my $fh = open "test.blol", :w, :bin;
$fh.write($out);
$fh.close();

say "Done.";
