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
		| <func-call-statm>
		| <expression>
	}

	rule expression {
		| <identifier>
		| <num-literal>
		| <group-expression>
	}

	rule group-expression {
		'(' <expression> ')'
	}

	rule if-statm {
		'if' <expression> <statement> ('else' <statement>)?
	}

	rule func-call-statm {
		<identifier> '(' <expression>* %% ',' ')'
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
}

class Type {
	has Int $.size;
}

class PrimitiveType is Type {
}

class StructType is Type {
	has %.fields;
}

class FuncDecl {
	has $.return-type;
	has @.params;
	has @.body;
}

my %primitive-types = %(
	int => PrimitiveType.new(size => 4),
	long => PrimitiveType.new(size => 8),
);

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
			die "Unknown type: $name"
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

		%.types{$name} = StructType.new(fields => %fields, size => $size);
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
			}
		}
	}
}

my $cst = Lol.parsefile('test.lol');

my $prog = Program.new();
$prog.register-defaults();
$prog.analyze($cst);

say $prog.funcs;
