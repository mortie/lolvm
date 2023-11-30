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
		| <assign-statm>
		| <expression>
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

	rule if-statm {
		'if' <expression> <statement> ('else' <statement>)?
	}

	rule assign-statm {
		<identifier> '=' <expression>
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
}

my %primitive-types = %(
	int => PrimitiveType.new(size => 4, desc => "int"),
	long => PrimitiveType.new(size => 8, desc => "long"),
);

class LocalVar {
	has Int $.index;
	has Type $.type;
}

class StackFrame {
	has LocalVar %.vars;
	has LocalVar @.temps;
	has Int $.idx is rw;
	has Int $.max-idx is rw;

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
		);
		$.idx += $type.size;
		if $.idx > $.max-idx {
			$.max-idx = $.idx;
		}
		@.temps.append($var);
		$var;
	}

	method pop-temp() {
		my $var = @.vars.pop();
		$.idx -= $var.type.size;
	}
}

class Program {
	has %.types;
	has %.funcs;

	method register-defaults() {
		for %primitive-types.kv -> $k, $v {
			%.types{$k} = $v;
		}
	}

	method lookup-type-from-cst($type-cst) {
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

	method find-expression-type($frame, $expr) {
		if $expr<num-literal>:exists {
			%primitive-types<int>;
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

	method compile-function($name, $func) {
		my $frame = StackFrame.new();
		$.populate-stack-frame($frame, $func.body<statement>);

		say "$name:";
		for $func.body<statement> -> $statm {
		}
	}

	method compile-functions() {
		for %.funcs.kv -> $name, $func {
			say "compiling function $name";
			$.compile-function($name, $func);
		}
	}
}

my $cst = Lol.parsefile('test.lol');

my $prog = Program.new();
$prog.register-defaults();
$prog.analyze($cst);
$prog.compile-functions();
