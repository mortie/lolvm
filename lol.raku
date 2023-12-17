#!/usr/bin/env raku

grammar Lol {
	rule TOP {
		^ <toplevel>* $
	}

	rule toplevel {
		| <struct-decl>
		| <method-decl>
		| <func-decl>
	}

	rule struct-decl {
		'struct' <identifier> <formal-type-params>? '{' <struct-fields> '}'
	}

	rule formal-type-params {
		'[' <formal-type-param>* %% ',' ']'
	}

	rule formal-type-param {
		<identifier>
	}

	rule struct-fields {
		<struct-field>* %% ';'
	}

	rule struct-field {
		<type> <identifier>
	}

	rule method-decl {
		<type> <identifier> '::' <identifier> <formal-type-params>? '(' <formal-params> ')' <block>
	}

	rule func-decl {
		<type> <identifier> <formal-type-params>? '(' <formal-params> ')' <block>
	}

	rule formal-params {
		(<type> <identifier>)* %% ','
	}

	rule block {
		'{' <statement>* %% ';' '}'
	}

	rule statement {
		| <block>
		| <dbg-print-statm>
		| <dump-statm>
		| <if-statm>
		| <while-statm>
		| <return-statm>
		| <decl-assign-statm>
		| <assign-statm>
		| <expression>
	}

	rule dbg-print-statm {
		'dbg-print' <expression>
	}

	rule dump-statm {
		'dump' <expression>
	}

	rule if-statm {
		'if' <expression> <statement> ('else' <statement>)?
	}

	rule while-statm {
		'while' <expression> <statement>
	}

	rule return-statm {
		'return' <expression>
	}

	rule decl-assign-statm {
		<identifier> '=' <expression>
	}

	rule assign-statm {
		<expression> '=' <expression>
	}

	rule expression {
		| <bin-op>
		| <method-call-level-expr>
	}

	rule bin-op {
		<method-call-level-expr> <bin-operator> <expression>
	}

	token bin-operator {
		'+' | '==' | "!=" | "<" | "<=" | ">" | ">="
	}

	rule method-call-level-expr {
		(<method-call> | <expression-part>) <locator-suffix>*
	}

	rule method-call {
		<expression-part> '!' <identifier> <type-params>? '(' <expression>* %% ',' ')'
	}

	rule locator-suffix {
		<locator-dereference> | <locator-member> | <locator-reference>
	}

	rule locator-dereference {
		'*'
	}

	rule locator-member {
		("'s" | '.') <identifier>
	}

	rule locator-reference {
		'&'
	}

	rule expression-part {
		| <uninitialized>
		| <sizeof>
		| <num-literal>
		| <bool-literal>
		| <func-call>
		| <brace-initializer>
		| <group-expression>
		| <identifier>
	}

	rule uninitialized {
		'uninitialized' <type>?
	}

	rule sizeof {
		'sizeof' <type>
	}

	rule func-call {
		<identifier> <type-params>? '(' <expression>* %% ',' ')'
	}

	rule brace-initializer {
		<type> <initializer-list>
	}

	rule initializer-list {
		| <sequence-initializer-list>
		| <designated-initializer-list>
	}

	rule sequence-initializer-list {
		'{' <expression>* %% ',' '}'
	}

	rule designated-initializer-list {
		'{' <designated-initializer>* %% ',' '}'
	}

	rule designated-initializer {
		<identifier> ':' <expression>
	}

	rule group-expression {
		'(' <expression> ')'
	}

	rule type {
		| <typeof>
		| <identifier> <type-params>?
	}

	rule typeof {
		'typeof' <expression>
	}

	rule type-params {
		'[' <type-param>+ %% ',' ']'
	}

	rule type-param {
		<type> | <type-param-int>
	}

	token type-param-int {
		'-'? \d+
	}

	token identifier {
		(<:alpha> | <:numeric> | '-' | '_')+
	}

	token num-literal {
		<num-literal-body> <num-literal-suffix>?
	}

	token num-literal-body {
		'-'? \d+ ('.' \d+)?
	}

	token num-literal-suffix {
		'b' | 'i' | 'l' | 'f' | 'd'
	}

	token bool-literal {
		true | false
	}

	token ws {
		(<!ww> \s+ | '//' \N* \n)*
	}
}

enum LolOp <
	SETI_8
	SETI_32
	SETI_64
	COPY_8
	COPY_32
	COPY_64
	COPY_N
	ADD_8
	ADD_32
	ADD_64
	ADD_F32
	ADD_F64
	ADDI_8
	ADDI_32
	ADDI_64
	EQ_8
	EQ_32
	EQ_64
	EQ_F32
	EQ_F64
	NEQ_8
	NEQ_32
	NEQ_64
	NEQ_F32
	NEQ_F64
	LT_U8
	LT_I32
	LT_I64
	LT_F32
	LT_F64
	LE_U8
	LE_I32
	LE_I64
	LE_F32
	LE_F64
	REF
	LOAD_8
	LOAD_32
	LOAD_64
	LOAD_N
	STORE_8
	STORE_32
	STORE_64
	STORE_N

	CALL
	RETURN
	BRANCH
	BRANCH_Z
	BRANCH_NZ
	DBG_PRINT_U8
	DBG_PRINT_I32
	DBG_PRINT_I64
	DBG_PRINT_F32
	DBG_PRINT_F64
	HALT
>;

sub generate-copy(Int $dest, Int $src, Int $size, Buf $out) {
	if $dest == $src {
		return;
	}

	if $size == 1 {
		$out.append(LolOp::COPY_8);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} elsif $size == 4 {
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

sub generate-load(Int $dest, Int $src, Int $size, Buf $out) {
	if $size == 0 {
		return;
	}

	if $size == 1 {
		$out.append(LolOp::LOAD_8);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} elsif $size == 4 {
		$out.append(LolOp::LOAD_32);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} elsif $size == 8 {
		$out.append(LolOp::LOAD_64);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} else {
		$out.append(LolOp::LOAD_N);
		append-i16le($out, $dest);
		append-i16le($out, $src);
		append-u32le($out, $size);
	}
}

sub generate-store(Int $dest, Int $src, Int $size, Buf $out) {
	if $size == 0 {
		return;
	}

	if $size == 1 {
		$out.append(LolOp::STORE_8);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} elsif $size == 4 {
		$out.append(LolOp::STORE_32);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} elsif $size == 8 {
		$out.append(LolOp::STORE_64);
		append-i16le($out, $dest);
		append-i16le($out, $src);
	} else {
		$out.append(LolOp::STORE_N);
		append-i16le($out, $dest);
		append-i16le($out, $src);
		append-u32le($out, $size);
	}
}

class Type {
	has Int $.size;
	has Str $.name;
}

class PrimitiveType is Type {
}

class Location {
	has Type $.type is rw;
}

class LocalLocation is Location {
	has Int $.index;
	has Bool $.temp is rw;
	has LocalLocation $.parent;

	method materialize($frame, Buf $out) returns LocalLocation {
		self;
	}
}

class FuncParam {
	has Type $.type;
	has Str $.name;
}

class FuncDecl {
	has Str $.name;
	has LocalLocation $.return-var;
	has FuncParam @.formal-params;
	has $.body;
	has %.aliases;

	has Int $.offset is rw = Nil;
}

class StructField {
	has Int $.offset;
	has Type $.type;
}

class StructType is Type {
	has StructField %.fields;
	has StructField @.field-list;
	has %.aliases;
	has FuncDecl %.methods;
	has %.method-templates;
}

class PointerType is Type {
	has Type $.pointee;
}

class ArrayType is Type {
	has Type $.elem;
	has Int $.elem-count;
}

class DereferenceLocation is Location {
	has LocalLocation $.local;
	has Int $.offset is rw;

	method materialize($frame, Buf $out) returns LocalLocation {
		if not $.local.type.isa(PointerType) {
			die "Can't materialize dereference of non-pointer type";
		}

		my $temp;
		if $.local.temp {
			$temp = $.local;
		} else {
			$temp = $frame.push-temp($.type);
		}

		if $.offset == 0 {
			generate-load($temp.index, $.local.index, $.type.size, $out);
			$frame.change-type($temp, $.type);
		} else {
			$out.append(LolOp::ADDI_64);
			append-i16le($out, $temp.index);
			append-i16le($out, $.local.index);
			append-u64le($out, $.offset);
			generate-load($temp.index, $temp.index, $.type.size, $out);
			$frame.change-type($temp, $.type);
		}

		$temp;
	}
}

my %builtin-types = %(
	void => PrimitiveType.new(size => 0, name => "void"),
	bool => PrimitiveType.new(size => 1, name => "bool"),
	byte => PrimitiveType.new(size => 1, name => "byte"),
	int => PrimitiveType.new(size => 4, name => "int"),
	long => PrimitiveType.new(size => 8, name => "long"),
	float => PrimitiveType.new(size => 4, name => "float"),
	double => PrimitiveType.new(size => 8, name => "double"),
);

class StackFrame {
	has FuncDecl $.func;
	has LocalLocation %.vars is rw;
	has LocalLocation @.temps is rw;
	has Int $.idx is rw = 0;

	method has-temps() returns Bool {
		@.temps.Bool;
	}

	method has(Str $name) returns Bool {
		%.vars{$name}:exists;
	}

	method get(Str $name) returns LocalLocation {
		if not %.vars{$name}:exists {
			die "Variable doesn't exist: $name";
		}

		%.vars{$name};
	}

	method define(Str $name, LocalLocation $var) {
		if %.vars{$name}:exists {
			die "Variable already exists: $name";
		}

		%.vars{$name} = $var;
	}

	method push-temp(Type $type) {
		my $var = LocalLocation.new(
			index => $.idx,
			type => $type,
			temp => True,
		);
		$.idx += $type.size;
		@.temps.append($var);
		$var;
	}

	method pop-if-temp(Location $var is rw) {
		if $var.isa(LocalLocation) {
			if not $var.temp {
				return;
			}

			while $var.parent.defined {
				$var = $var.parent;
			}

			my $popped-var = @.temps.pop();
			if not ($var === $popped-var) {
				die "Popped non-top-of-stack '{$var.type.name}' variable at index {$var.index} " ~
					"(top '{$var.type.name}' has index {$popped-var.index})";
			}

			$.idx -= $var.type.size;
		} elsif $var.isa(DereferenceLocation) {
			$.pop-if-temp($var.local);
		} else {
			die "Bad location '$var'";
		}
	}

	method change-type(LocalLocation $var, Type $new-type) {
		if not ($var === @.temps.tail) {
			die "Can't change type of a variable that's not the last on the stack"
		}

		$var.type = $new-type;
		my $size-diff = $new-type.size - $var.type.size;
		$.idx += $size-diff;
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

sub append-u64le(Buf $buf, uint64 $value) {
	$buf.write-uint64(+$buf, $value, LittleEndian);
}

sub append-i64le(Buf $buf, int64 $value) {
	$buf.write-int64(+$buf, $value, LittleEndian);
}

sub append-num32le(Buf $buf, num32 $value) {
	$buf.write-num32(+$buf, $value, LittleEndian);
}

sub append-num64le(Buf $buf, num64 $value) {
	$buf.write-num64(+$buf, $value, LittleEndian);
}

class FuncCallFixup {
	has uint32 $.location;
	has Str $.name;
};

class Program {
	has Type %.types;
	has %.struct-templates;
	has FuncDecl %.funcs;
	has %.func-templates;
	has FuncDecl %.materialized-func-templates;

	has FuncCallFixup @.func-call-fixups;
	has FuncCallFixup @.func-template-call-fixups;

	method register-defaults() {
		for %builtin-types.kv -> $k, $v {
			%.types{$k} = $v;
		}
	}

	method get-pointer-type-to(Type $pointee) {
		my $name = "ptr[{$pointee.name}]";
		if %.types{$name}:exists {
			%.types{$name};
		} else {
			my $type = PointerType.new(
				pointee => $pointee,
				size => 8,
				name => $name,
			);
			%.types{$name} = $type;
			$type;
		}
	}

	method get-array-type(Type $elem, Int $count) {
		my $name = "array[{$elem.name},$count]";
		if %.types{$name}:exists {
			%.types{$name};
		} else {
			my $type = ArrayType.new(
				elem => $elem,
				elem-count => $count,
				size => $elem.size * $count,
				name => $name,
			);
			%.types{$name} = $type;
			$type;
		}
	}

	method get-struct-type-from-template($name is rw, $struct-template, @params, %aliases) {
		$name ~= "[";
		my $first = True;
		for @params -> $param {
			if not $first {
				$name ~= ","
			}
			$first = False;

			if $param.isa(Type) {
				$name ~= $param.name;
			} else {
				$name ~= $param.Str;
			}
		}
		$name ~= "]";

		if %.types{$name}:exists {
			return %.types{$name};
		}

		my @formal-params = $struct-template<formal-type-params><formal-type-param>;
		if +@formal-params != +@params {
			die "'{$name}' expects {+@formal-params} type parameters, got {+@params}";
		}

		my %new-aliases = %();
		for @formal-params Z @params -> ($formal-param, $param) {
			%new-aliases{$formal-param<identifier>.Str} = $param
		}

		my %fields;
		my @field-list;
		my $size = 0;
		for $struct-template<struct-fields><struct-field> -> $struct-field-cst {
			my $field-type = $.type-from-cst($struct-field-cst<type>, %new-aliases, StackFrame.new());
			my $field-name = $struct-field-cst<identifier>.Str;

			if %fields{$field-name}:exists {
				die "Duplicate field name: $field-name";
			}

			my $field = StructField.new(
				offset => $size,
				type => $field-type,
			);
			%fields{$field-name} = $field;
			@field-list.append($field);
			$size += $field-type.size;
		}

		my $type = StructType.new(
			fields => %fields,
			field-list => @field-list,
			aliases => %new-aliases,
			methods => %(),
			method-templates => %(),
			size => $size,
			name => "$name",
		);
		%.types{$name} = $type;
		return $type;
	}

	method type-params-from-cst($type-params-cst, %aliases, $frame) {
		my @params;
		for $type-params-cst<type-param> -> $param {
			my $alias;
			if $param<type> and $param<type><identifier> {
				my $type-name = $param<type><identifier>.Str;
				if %aliases{$type-name} and not $param<type>[0] {
					$alias = %aliases{$type-name};
				}
			}

			if $alias.defined {
				@params.append($alias);
			} elsif $param<type> {
				@params.append($.type-from-cst($param<type>, %aliases, $frame));
			} elsif $param<type-param-int> {
				@params.append(+$param<type-param-int>);
			} else {
				die "Oh noes";
			}
		}
		@params;
	}

	method type-from-cst($type-cst, %aliases, $frame) returns Type {
		if $type-cst<typeof> {
			return $.get-expr-type($frame, $type-cst<typeof><expression>, %aliases);
		}

		my $name = $type-cst<identifier>.Str;

		if %aliases{$name}:exists and not $type-cst[0] {
			my $param = %aliases{$name};
			if $param.isa(Type) {
				return $param;
			} elsif $param.isa(Int) {
				die "Integer type parameter not expected here";
			} else {
				die "Bad type alias '$param'";
			}
		}

		my @params;
		if $type-cst<type-params> {
			@params = @.type-params-from-cst($type-cst<type-params>, %aliases, $frame);
		}

		if $name eq "ptr" {
			if +@params != 1 {
				die "'ptr' requires 1 type parameter";
			}

			if not @params[0].isa(Type) {
				die "'ptr' requires its type parameter to be a type"
			}

			my $pointee = @params[0];
			$.get-pointer-type-to($pointee);
		} elsif $name eq "array" {
			if +@params != 2 {
				die "'array' requires 2 type parameters";
			}

			if not @params[0].isa(Type) {
				die "'array' requires its first type parameter to be a type";
			}

			if not @params[1].isa(Int) {
				die "'array' requires its second type parameter to be an integer";
			}

			$.get-array-type(@params[0], @params[1]);
		} elsif %.struct-templates{$name}:exists {
			if +@params == 0 {
				die "'{$name}' requires type parameters";
			}

			my $struct-template = %.struct-templates{$name};
			$.get-struct-type-from-template($name, $struct-template, @params, %aliases);
		} elsif %.types{$name}:exists {
			%.types{$name};
		} else {
			die "Unknown type: '$name'"
		}
	}

	method type-from-brace-initializer-cst($brace-initializer-cst, %aliases, $frame) returns Type {
		my $type-cst = $brace-initializer-cst<type>;
		my $list-cst = $brace-initializer-cst<initializer-list>;
		my @type-params-cst;
		if $type-cst<type-params> {
			@type-params-cst = $type-cst<type-params><type-param>;
		}

		if $type-cst<identifier>.Str eq "array" and +@type-params-cst == 1 {
			if not $list-cst<sequence-initializer-list> {
				die "'array' don't work with designated initializers";
			}

			if not @type-params-cst[0]<type> {
				die "'array' requires its first type parameter to be a type";
			}

			my $elem-type = $.type-from-cst(@type-params-cst[0]<type>, %aliases, $frame);
			$.get-array-type($elem-type, +$list-cst<sequence-initializer-list><expression>);
		} else {
			$.type-from-cst($type-cst, %aliases, $frame);
		}
	}

	method analyze-struct-decl($struct-decl) {
		my $name = $struct-decl<identifier>.Str;
		if $.types{$name}:exists {
			die "A type named $name already exists!";
		}

		if $struct-decl<formal-type-params>:exists {
			%.struct-templates{$name} = $struct-decl;
			return;
		}

		my %fields;
		my @field-list;
		my $size = 0;
		for $struct-decl<struct-fields><struct-field> -> $struct-field-cst {
			if %.struct-templates{$name}:exists {
				die "A function template named $name already exists!";
			}

			my $field-type = $.type-from-cst($struct-field-cst<type>, %(), StackFrame.new());
			my $field-name = $struct-field-cst<identifier>.Str;

			if %fields{$field-name}:exists {
				die "Duplicate field name: $field-name";
			}

			my $field = StructField.new(
				offset => $size,
				type => $field-type,
			);
			%fields{$field-name} = $field;
			@field-list.append($field);
			$size += $field-type.size;
		}

		%.types{$name} = StructType.new(
			fields => %fields,
			field-list => @field-list,
			aliases => %(),
			methods => %(),
			method-templates => %(),
			size => $size,
			name => "$name",
		);
	}

	method create-func-decl($name, $func-decl-cst, %aliases) {
		my $return-type = $.type-from-cst($func-decl-cst<type>, %aliases, StackFrame.new());
		my $return-index = -$return-type.size;

		my @formal-params;
		for $func-decl-cst<formal-params>[0] -> $formal-param-cst {
			my $type = $.type-from-cst($formal-param-cst<type>, %aliases, StackFrame.new());
			$return-index -= $type.size;
			@formal-params.push(FuncParam.new(
				type => $type,
				name => $formal-param-cst<identifier>.Str,
			));
		}

		FuncDecl.new(
			name => $name,
			return-var => LocalLocation.new(
				index => $return-index,
				type => $return-type,
				temp => False,
			),
			formal-params => @formal-params,
			body => $func-decl-cst<block>,
			aliases => %aliases,
		);
	}

	method analyze-func-decl($func-decl-cst) {
		my $name = $func-decl-cst<identifier>.Str;
		if %.funcs{$name}:exists {
			die "A function named $name already exists!";
		}

		if $func-decl-cst<formal-type-params>:exists {
			if %.func-templates{$name}:exists {
				die "A function template named $name already exists!";
			}

			%.func-templates{$name} = $func-decl-cst;
			return;
		}

		my $func = $.create-func-decl($name, $func-decl-cst, %());
		%.funcs{$name} = $func;
	}

	method analyze-method-decl($method-decl-cst) {
		my $struct-name = $method-decl-cst<identifier>[0].Str;
		my $method-name = $method-decl-cst<identifier>[1].Str;

		if not %.types{$struct-name} {
			die "Declared method on unknown type '$struct-name'"
		}

		my $struct = %.types{$struct-name};
		if not $struct.isa(StructType) {
			die "Declared method on non-struct type '{$struct.name}'";
		}

		if $struct.methods{$method-name}:exists {
			die "Method '$method-name' already exists on '{$struct.name}'";
		}

		if $method-decl-cst<formal-type-params>:exists {
			die "TODO: methods on struct templates";
		}

		my $name = $struct.name ~ "::" ~ $method-name;
		my $func = $.create-func-decl($name, $method-decl-cst, %(self => $struct));
		$struct.methods{$method-name} = $func;
		%.funcs{$name} = $func;
	}

	method analyze($cst) {
		for $cst<toplevel> -> $toplevel {
			if $toplevel<struct-decl> {
				$.analyze-struct-decl($toplevel<struct-decl>);
			} elsif $toplevel<func-decl> {
				$.analyze-func-decl($toplevel<func-decl>);
			} elsif $toplevel<method-decl> {
				$.analyze-method-decl($toplevel<method-decl>);
			} else {
				die "Bad toplevel $toplevel";
			}
		}
	}

	method reconcile-types(Type $lhs, Type $rhs) returns Type {
		if not ($lhs === $rhs) {
			die "Incompatible types: {$lhs.name}, {$rhs.name}"
		}

		$lhs;
	}

	method resolve-func-decl($func-call-cst, %aliases, $frame) returns FuncDecl {
		my $name = $func-call-cst<identifier>.Str;

		if %.funcs{$name} {
			if $func-call-cst<actual-type-params>:exists {
				die "Type parameters provided to non-template function";
			}

			return %.funcs{$name};
		} elsif %.func-templates{$name} {
			if not $func-call-cst<type-params>:exists {
				die "No type parameters provided for template function";
			}

			my $func-decl-cst = %.func-templates{$name};

			my @params = @.type-params-from-cst($func-call-cst<type-params>, %aliases, $frame);
			$name ~= "[";
			my $first = True;
			for @params -> $param {
				if not $first {
					$name ~= ","
				}
				$first = False;

				if $param.isa(Type) {
					$name ~= $param.name;
				} else {
					$name ~= $param.Str;
				}
			}
			$name ~= "]";

			if %.materialized-func-templates{$name} {
				return %.materialized-func-templates{$name};
			}

			my @formal-params = $func-decl-cst<formal-type-params><formal-type-param>;
			if +@formal-params != +@params {
				die "'{$func-decl-cst<identifier>.Str}' expects {+@formal-params} type " ~
				"parameters, got {+@params}";
			}

			my %new-aliases = %();
			for @formal-params Z @params -> ($formal-param, $param) {
				%new-aliases{$formal-param<identifier>.Str} = $param;
			}

			my $func = $.create-func-decl($name, $func-decl-cst, %new-aliases);
			%.materialized-func-templates{$name} = $func;
			$func;
		} else {
			die "Unknown function: {$name}";
		}
	}

	method compile-expr-part($frame, $part, Buf $out, %aliases) returns Location {
		if $part<uninitialized> {
			if not $part<uninitialized><type> {
				die "Missing type";
			}

			$frame.push-temp($.type-from-cst($part<uninitialized><type>, %aliases, $frame));
		} elsif $part<sizeof> {
			my $type = $.type-from-cst($part<sizeof><type>, %aliases, $frame);
			my $var = $frame.push-temp(%builtin-types<long>);
			$out.append(LolOp::SETI_64);
			append-i16le($out, $var.index);
			append-u64le($out, $type.size);
			$var;
		} elsif $part<num-literal> {
			my $body = $part<num-literal><num-literal-body>.Str;

			my $suffix;
			if $part<num-literal><num-literal-suffix> {
				$suffix = $part<num-literal><num-literal-suffix>.Str;
			} elsif $body.contains(".") {
				$suffix = "d";
			} else {
				$suffix = "i";
			}

			my $var;
			if $suffix eq "b" {
				$var = $frame.push-temp(%builtin-types<byte>);
				$out.append(LolOp::SETI_8);
				append-i16le($out, $var.index);
				$out.append(+$body);
			} elsif $suffix eq "i" {
				$var = $frame.push-temp(%builtin-types<int>);
				$out.append(LolOp::SETI_32);
				append-i16le($out, $var.index);
				append-i32le($out, +$body);
			} elsif $suffix eq "l" {
				$var = $frame.push-temp(%builtin-types<long>);
				$out.append(LolOp::SETI_64);
				append-i16le($out, $var.index);
				append-i64le($out, +$body);
			} elsif $suffix eq "f" {
				$var = $frame.push-temp(%builtin-types<float>);
				$out.append(LolOp::SETI_32);
				append-i16le($out, $var.index);
				append-num32le($out, (+$body).Num);
			} elsif $suffix eq "d" {
				$var = $frame.push-temp(%builtin-types<double>);
				$out.append(LolOp::SETI_64);
				append-i16le($out, $var.index);
				append-num64le($out, (+$body).Num);
			} else {
				die "Bad number literal suffix '$suffix'"
			}

			$var;
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
		} elsif $part<func-call> {
			my $func = $.resolve-func-decl($part<func-call>, %aliases, $frame);

			my $return-val = $frame.push-temp($func.return-var.type);
			my $stack-bump = $frame.idx;
			my @param-vars;
			for 0..^+$func.formal-params -> $i {
				my $param = $func.formal-params[$i];
				$stack-bump += $param.type.size;

				my $expr = $part<func-call><expression>[$i];
				my $loc = $frame.push-temp($param.type);
				$.compile-expr-to-loc($frame, $loc, $expr, $out, %aliases);
				@param-vars.append($loc);
			}

			$out.append(LolOp::CALL);
			append-i16le($out, $stack-bump);

			if $func.offset.defined {
				append-u32le($out, $func.offset);
			} else {
				$.func-call-fixups.append(FuncCallFixup.new(
					location => +$out,
					name => $func.name,
				));
				append-u32le($out, 0);
			}

			while @param-vars {
				my $var = @param-vars.pop();
				$frame.pop-if-temp($var);
			}

			$return-val;
		} elsif $part<brace-initializer> {
			my $type = $.type-from-brace-initializer-cst($part<brace-initializer>, %aliases, $frame);
			my $var = $frame.push-temp($type);
			$.compile-expr-part-to-loc($frame, $var, $part, $out, %aliases);
			$var;
		} elsif $part<group-expression> {
			$.compile-expr($frame, $part<group-expression><expression>, $out, %aliases);
		} elsif $part<identifier> {
			$frame.get($part<identifier>.Str);
		} else {
			die "Bad expression '$part'";
		}
	}

	method compile-expr-part-to-loc($frame, LocalLocation $dest, $part, Buf $out, %aliases) {
		if $part<uninitialized> {
			if $part<uninitialized><type> {
				my $type = $.type-from-cst($part<uninitialized><type>, %aliases, $frame);
				$.reconcile-types($dest.type, $type);
			} else {
				# Don't care, use the existing type
			}
		} elsif $part<sizeof> {
			my $type = $.type-from-cst($part<sizeof><type>, $frame);
			$.reconcile-types($dest.type, %builtin-types<long>);
			$out.append(LolOp::SETI_64);
			append-i16le($out, $dest.index);
			append-u64le($out, $type.size);
		} elsif $part<bool-literal> {
			$.reconcile-types($dest.type, %builtin-types<bool>);
			$out.append(LolOp::SETI_8);
			append-i16le($out, $dest.index);
			if $part<bool-literal>.Str eq "true" {
				$out.append(1);
			} elsif $part<bool-literal>.Str eq "false" {
				$out.append(0);
			} else {
				die "Bad bool '{$part<bool-literal>}'";
			}
		} elsif $part<brace-initializer> {
			my $init-list = $part<brace-initializer><initializer-list>;
			if $dest.type.isa(ArrayType) {
				if not $init-list<sequence-initializer-list> {
					die "Array initializer must be a sequence initializer list";
				}

				my @seq = $init-list<sequence-initializer-list><expression>;
				if +@seq != $dest.type.elem-count {
					die "Can't initialize '$dest.type.name' with {+@seq} elements";
				}

				my $idx = 0;
				for @seq -> $elem-expr {
					my $loc = LocalLocation.new(
						index => $dest.index + $idx,
						temp => False,
						type => $dest.type.elem,
					);
					$.compile-expr-to-loc($frame, $loc, $elem-expr, $out, %aliases);
				}
			} elsif $dest.type.isa(StructType) and $init-list<sequence-initializer-list> {
				my @seq = $init-list<sequence-initializer-list><expression>;
				if +@seq != +$dest.type.field-list {
					die "Can't initialize '{$dest.type.name}' with {+@seq} elements";
				}

				for $dest.type.field-list Z @seq -> ($field, $elem-expr) {
					my $loc = LocalLocation.new(
						index => $dest.index + $field.offset,
						temp => False,
						type => $field.type,
					);
					$.compile-expr-to-loc($frame, $loc, $elem-expr, $out, %aliases);
				}
			} elsif $dest.type.isa(StructType) and $init-list<designated-initializer-list> {
				my @seq = $init-list<designated-initializer-list><designated-initializer>;

				my %initialized-fields;
				for @seq -> $initializer {
					my $field-name = $initializer<identifier>.Str;
					my $elem-expr = $initializer<expression>;
					if not $dest.type.fields{$field-name} {
						die "Field '$field-name' not in '{$dest.type.name}'";
					}

					if %initialized-fields{$field-name}:exists {
						die "Field '$field-name' already initialized";
					}

					my $field = $dest.type.fields{$field-name};

					my $loc = LocalLocation.new(
						index => $dest.index + $field.offset,
						temp => False,
						type => $field.type,
					);
					$.compile-expr-to-loc($frame, $loc, $elem-expr, $out, %aliases);
					%initialized-fields{$field-name} = True;
				}

				for $dest.type.fields.keys -> $field-name {
					if not %initialized-fields{$field-name}:exists {
						die "Field '$field-name' not initiaized";
					}
				}
			} else {
				die "Can't brace-initialize '{$dest.type.name}'";
			}
		} else {
			my $src = $.compile-expr-part($frame, $part, $out, %aliases)
			.materialize($frame, $out);
			my $type = $.reconcile-types($dest.type, $src.type);
			generate-copy($dest.index, $src.index, $type.size, $out);
			$frame.pop-if-temp($src);
		}
	}

	method get-expr-part-type($frame, $part, %aliases) returns Type {
		my $var = $.compile-expr-part($frame, $part, Buf.new(), %aliases);
		$frame.pop-if-temp($var);
		$var.type;
	}

	# dest can alias lhs or rhs.
	method compile-bin-op(
		Int $dest, LocalLocation $lhs, LocalLocation $rhs, Str $operator, Buf $out
	) returns Type {
		my $src-type = $.reconcile-types($lhs.type, $rhs.type);

		my $swap-opers = False;
		my Type $dest-type;

		if $src-type === %builtin-types<bool> {
			if $operator eq "==" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::EQ_8);
			} elsif $operator eq "!=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::NEQ_8);
			} else {
				die "Bad operator: '$operator'";
			}
		} elsif $src-type === %builtin-types<byte> {
			if $operator eq "+" {
				$dest-type = %builtin-types<byte>;
				$out.append(LolOp::ADD_8);
			} elsif $operator eq "==" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::EQ_8);
			} elsif $operator eq "!=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::NEQ_8);
			} elsif $operator eq "<" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_U8);
			} elsif $operator eq "<=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_U8);
			} elsif $operator eq ">" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_U8);
				$swap-opers = True;
			} elsif $operator eq ">=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_U8);
				$swap-opers = True;
			} else {
				die "Bad operator: '$operator'";
			}
		} elsif $src-type === %builtin-types<int> {
			if $operator eq "+" {
				$dest-type = %builtin-types<int>;
				$out.append(LolOp::ADD_32);
			} elsif $operator eq "==" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::EQ_32);
			} elsif $operator eq "!=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::NEQ_32);
			} elsif $operator eq "<" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_I32);
			} elsif $operator eq "<=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_I32);
			} elsif $operator eq ">" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_I32);
				$swap-opers = True;
			} elsif $operator eq ">=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_I32);
				$swap-opers = True;
			} else {
				die "Bad operator: '$operator'";
			}
		} elsif $src-type === %builtin-types<long> {
			if $operator eq "+" {
				$dest-type = %builtin-types<long>;
				$out.append(LolOp::ADD_64);
			} elsif $operator eq "==" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::EQ_64);
			} elsif $operator eq "!=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::NEQ_64);
			} elsif $operator eq "<" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_I64);
			} elsif $operator eq "<=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_I64);
			} elsif $operator eq ">" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_I64);
				$swap-opers = True;
			} elsif $operator eq ">=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_I64);
				$swap-opers = True;
			} else {
				die "Bad operator: '$operator'";
			}
		} elsif $src-type === %builtin-types<float> {
			if $operator eq "+" {
				$dest-type = %builtin-types<float>;
				$out.append(LolOp::ADD_F32);
			} elsif $operator eq "==" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::EQ_F32);
			} elsif $operator eq "!=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::NEQ_F32);
			} elsif $operator eq "<" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_F32);
			} elsif $operator eq "<=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_F32);
			} elsif $operator eq ">" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_F32);
				$swap-opers = True;
			} elsif $operator eq ">=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_F32);
				$swap-opers = True;
			} else {
				die "Bad operator: '$operator'";
			}
		} elsif $src-type === %builtin-types<double> {
			if $operator eq "+" {
				$dest-type = %builtin-types<double>;
				$out.append(LolOp::ADD_F64);
			} elsif $operator eq "==" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::EQ_F64);
			} elsif $operator eq "!=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::NEQ_F64);
			} elsif $operator eq "<" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_F64);
			} elsif $operator eq "<=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_F64);
			} elsif $operator eq ">" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LT_F64);
				$swap-opers = True;
			} elsif $operator eq ">=" {
				$dest-type = %builtin-types<bool>;
				$out.append(LolOp::LE_F64);
				$swap-opers = True;
			} else {
				die "Bad operator: '$operator'";
			}
		} else {
			die "Bad type: '{$src-type.name}'";
		}

		append-i16le($out, $dest);
		if $swap-opers {
			append-i16le($out, $rhs.index);
			append-i16le($out, $lhs.index);
		} else {
			append-i16le($out, $lhs.index);
			append-i16le($out, $rhs.index);
		}

		$dest-type;
	}

	method compile-method-call-level-expr($frame, $mcexpr, Buf $out, %aliases) returns Location {
		my $expr = $mcexpr[0];
		my $var;
		if $expr<method-call> {
			my $type = $.get-expr-part-type($frame, $expr<method-call><expression-part>, %aliases);
			if $type.isa(PointerType) {
				$type = $type.pointee;
			}

			if not $type.isa(StructType) {
				die "Method call on non-struct type '{$type.name}'";
			}

			my $method-name = $expr<method-call><identifier>.Str;
			if not $type.methods{$method-name} {
				die "Method '$method-name' doesn't exist on '{$type.name}'";
			}

			my $func = $type.methods{$method-name};

			my $return-val = $frame.push-temp($func.return-var.type);
			my $stack-bump = $frame.idx;
			my @param-vars;
			for 0..^+$func.formal-params -> $i {
				my $param = $func.formal-params[$i];
				$stack-bump += $param.type.size;

				my $loc = $frame.push-temp($param.type);
				if $i == 0 {
					my $part = $expr<method-call><expression-part>;
					$.compile-expr-part-to-loc($frame, $loc, $part, $out, %aliases);
				} else {
					my $e = $expr<method-call><expression>[$i - 1];
					$.compile-expr-to-loc($frame, $loc, $e, $out, %aliases);
				}
				@param-vars.append($loc);
			}

			$out.append(LolOp::CALL);
			append-i16le($out, $stack-bump);

			if $func.offset.defined {
				append-u32le($out, $func.offset);
			} else {
				$.func-call-fixups.append(FuncCallFixup.new(
					location => +$out,
					name => $func.name,
				));
				append-u32le($out, 0);
			}

			while @param-vars {
				my $loc = @param-vars.pop();
				$frame.pop-if-temp($loc);
			}

			$var = $return-val;
		} elsif $expr<expression-part> {
			$var = $.compile-expr-part($frame, $expr<expression-part>, $out, %aliases);
		} else {
			die "Bad expression '$expr'";
		}

		for $mcexpr<locator-suffix> -> $suffix {
			if $suffix<locator-member> {
				if not $var.type.isa(StructType) {
					die "Member access requires a struct type, got '{$var.type.name}'";
				}

				my $name = $suffix<locator-member><identifier>.Str;
				if not $var.type.fields{$name}:exists {
					die "Member '$name' doesn't exist in '{$var.type.name}'";
				}

				my $field = $var.type.fields{$name};

				if $var.isa(LocalLocation) {
					$var = LocalLocation.new(
						type => $field.type,
						index => $var.index + $field.offset,
						temp => $var.temp,
						parent => $var,
					);
				} elsif $var.isa(DereferenceLocation) {
					$var = DereferenceLocation.new(
						offset => $var.offset + $field.offset,
						local => $var.local,
						type => $field.type,
					);
				} else {
					die "Bad variable: $var"
				}
			} elsif $suffix<locator-dereference> {
				if not $var.type.isa(PointerType) {
					die "Dereference of non-pointer type '{$var.type.name}'";
				}

				my $local = $var.materialize($frame, $out);
				$var = DereferenceLocation.new(
					offset => 0,
					local => $local,
					type => $var.type.pointee,
				);
			} elsif $suffix<locator-reference> {
				if $var.isa(LocalLocation) {
					if $var.temp {
						die "Refusing to take the reference of a temporary";
					}

					my $temp = $frame.push-temp($.get-pointer-type-to($var.type));
					$out.append(LolOp::REF);
					append-i16le($out, $temp.index);
					append-i16le($out, $var.index);
					$var = $temp;
				} else {
					die "Can't take reference of non-local yet";
				}
			} else {
				die "Bad suffix: $suffix";
			}
		}

		$var;
	}

	method compile-method-call-level-expr-to-loc($frame, LocalLocation $dest, $expr, Buf $out, %aliases) {
		if $expr<expression-part> {
			$.compile-expr-part-to-loc($frame, $dest, $expr<expression-part>, $out, %aliases);
		} else {
			my $src = $.compile-method-call-level-expr($frame, $expr, $out, %aliases);
			my $type = $.reconcile-types($dest.type, $src.type);
			generate-copy($dest.index, $src.index, $type.size, $out);
			$frame.pop-if-temp($src);
		}
	}

	method compile-expr($frame, $expr, Buf $out, %aliases) returns Location {
		CATCH {
			die "{.Str}\n  in expr: ({$expr.Str})";
		}

		if $expr<bin-op> {
			my $operator = $expr<bin-op><bin-operator>.Str;
			my $lhs = $.compile-method-call-level-expr(
				$frame, $expr<bin-op><method-call-level-expr>, $out, %aliases)
					.materialize($frame, $out);
			my $rhs = $.compile-expr($frame, $expr<bin-op><expression>, $out, %aliases)
				.materialize($frame, $out);
			if $lhs.temp {
				my $type = $.compile-bin-op($lhs.index, $lhs, $rhs, $operator, $out);
				$frame.pop-if-temp($rhs);
				$frame.change-type($lhs, $type);
				$lhs;
			} elsif $rhs.temp {
				my $type = $.compile-bin-op($rhs.index, $lhs, $rhs, $operator, $out);
				$frame.change-type($rhs, $type);
				$rhs;
			} else {
				my $var = $frame.push-temp(%builtin-types<void>);
				my $type = $.compile-bin-op($rhs.index, $lhs, $rhs, $operator, $out);
				$frame.change-type($var, $type);
				$var;
			}
		} elsif $expr<method-call-level-expr> {
			$.compile-method-call-level-expr($frame, $expr<method-call-level-expr>, $out, %aliases);
		} else {
			die "Bad expression '$expr'";
		}
	}

	method compile-expr-to-loc($frame, LocalLocation $dest, $expr, Buf $out, %aliases) {
		if $expr<bin-op> {
			my $operator = $expr<bin-op><bin-operator>.Str;
			my $lhs = $.compile-expr-part($frame, $expr<bin-op><expression-part>, $out, %aliases)
				.materialize($frame, $out);
			my $rhs = $.compile-expr($frame, $expr<bin-op><expression>, $out, %aliases)
				.materialize($frame, $out);

			my $type = $.compile-bin-op($dest.index, $lhs, $rhs, $operator, $out);
			if not ($type === $dest.type) {
				die "Expression resulted in '{$type.name}', expected '{$dest.type}'";
			}

			$frame.pop-if-temp($rhs);
			$frame.pop-if-temp($lhs);
		} elsif $expr<method-call-level-expr> {
			$.compile-method-call-level-expr-to-loc(
				$frame, $dest, $expr<method-call-level-expr>[0], $out, %aliases);
		} else {
			die "Bad expression '$expr'";
		}
	}

	method get-expr-type($frame, $expr, %aliases) returns Type {
		my @func-call-fixups = @.func-call-fixups.clone();
		my @func-template-call-fixups = @.func-template-call-fixups.clone();
		my %materialized-func-templates = %.materialized-func-templates.clone();

		my $var = $.compile-expr($frame, $expr, Buf.new(), %aliases);
		$frame.pop-if-temp($var);

		@.func-call-fixups = @func-call-fixups;
		@.func-template-call-fixups = @func-template-call-fixups;
		%.materialized-func-templates = %materialized-func-templates;

		$var.type;
	}

	method compile-statm($frame, $statm, Buf $out, %aliases) {
		CATCH {
			die "{.Str}\n  in statm: {$statm.Str}\n";
		}

		if $statm<block> {
			$.compile-block($frame, $statm<block>, $out, %aliases);
		} elsif $statm<dbg-print-statm> {
			my $var = $.compile-expr($frame, $statm<dbg-print-statm><expression>, $out, %aliases)
				.materialize($frame, $out);
			if $var.type === %builtin-types<bool> {
				$out.append(LolOp::DBG_PRINT_U8);
			} elsif $var.type === %builtin-types<int> {
				$out.append(LolOp::DBG_PRINT_I32);
			} elsif $var.type === %builtin-types<long> or $var.type.isa(PointerType) {
				$out.append(LolOp::DBG_PRINT_I64);
			} elsif $var.type === %builtin-types<float> {
				$out.append(LolOp::DBG_PRINT_F32);
			} elsif $var.type === %builtin-types<double> {
				$out.append(LolOp::DBG_PRINT_F64);
			} else {
				die "Type incompatible with dbg-print: '{$var.type.name}'";
			}

			append-i16le($out, $var.index);
			$frame.pop-if-temp($var);
		} elsif $statm<dump-statm> {
			my $dummy-out = Buf.new();
			my $var = $.compile-expr($frame, $statm<dump-statm><expression>, $dummy-out, %aliases);
			say "    Dump expression ({$statm<dump-statm><expression>.Str}):";
			say "      Type: '{$var.type.name}' (size {$var.type.size})";
			if $var.temp {
				say "      Index: {$var.index} (temporary)";
			} else {
				say "      Index: {$var.index} (non-temporary)";
			}

			if +$dummy-out > 0 {
				say "      Codegen size: {+$dummy-out} bytes";
			}

			$frame.pop-if-temp($var);
		} elsif $statm<if-statm> {
			my $cond-var = $.compile-expr($frame, $statm<if-statm><expression>, $out, %aliases);
			my $if-start-idx = +$out;
			$out.append(LolOp::BRANCH_Z);
			append-i16le($out, $cond-var.index);
			my $fixup-skip-if-body-idx = +$out;
			$out.append(0, 0);
			$frame.pop-if-temp($cond-var);

			$.compile-statm($frame, $statm<if-statm><statement>, $out, %aliases);

			if $statm<if-statm>[0] {
				my $else-start-idx = +$out;
				$out.append(LolOp::BRANCH);
				my $fixup-skip-else-body-idx = +$out;
				$out.append(0, 0);

				$out.write-int16($fixup-skip-if-body-idx, +$out - $if-start-idx, LittleEndian);

				$.compile-statm($frame, $statm<if-statm>[0]<statement>, $out, %aliases);
				$out.write-int16($fixup-skip-else-body-idx, +$out - $else-start-idx, LittleEndian);
			} else {
				$out.write-int16($fixup-skip-if-body-idx, +$out - $if-start-idx, LittleEndian);
			}
		} elsif $statm<while-statm> {
			my $while-start-idx = +$out;
			my $cond-var = $.compile-expr($frame, $statm<while-statm><expression>, $out, %aliases);
			my $skip-body-branch-idx = +$out;
			$out.append(LolOp::BRANCH_Z);
			append-i16le($out, $cond-var.index);
			my $fixup-skip-body-idx = +$out;
			append-i16le($out, 0);
			$frame.pop-if-temp($cond-var);

			$.compile-statm($frame, $statm<while-statm><statement>, $out, %aliases);

			my $jump-back-delta = $while-start-idx - +$out;
			$out.append(LolOp::BRANCH);
			append-i16le($out, $jump-back-delta);

			$out.write-int16($fixup-skip-body-idx, +$out - $skip-body-branch-idx, LittleEndian);
		} elsif $statm<return-statm> {
			$.compile-expr-to-loc(
				$frame, $frame.func.return-var, $statm<return-statm><expression>, $out, %aliases);
		} elsif $statm<decl-assign-statm> {
			my $name = $statm<decl-assign-statm><identifier>.Str;
			my $expr = $statm<decl-assign-statm><expression>;

			if $frame.has($name) {
				$.compile-expr-to-loc($frame, $frame.get($name), $expr, $out, %aliases);
			} else {
				if $frame.has-temps() {
					die "Got declare assign statement while there are temporaries?";
				}

				my $var = $.compile-expr($frame, $expr, $out, %aliases).materialize($frame, $out);
				if not $var.temp {
					my $new-var = $frame.push-temp($var.type);
					generate-copy($new-var.index, $var.index, $var.type.size, $out);
					$var = $new-var;
				}

				$frame.temps.pop();
				$var.temp = False;
				$frame.define($name, $var);
				$var;
			}
		} elsif $statm<assign-statm> {
			my $var = $.compile-expr($frame, $statm<assign-statm><expression>[0], $out, %aliases);
			my $expr = $statm<assign-statm><expression>[1];
			if $var.isa(LocalLocation) {
				if $var.temp {
					die "Can't assign to temporary location";
				}

				$.compile-expr-to-loc($frame, $var, $expr, $out, %aliases);
			} elsif $var.isa(DereferenceLocation) {
				my $temp = $.compile-expr($frame, $expr, $out, %aliases);
				if not ($temp.type === $var.type) {
					die "Expected '{$var.type.name}', got '{$temp.type.name}'";
				}
				if $var.offset == 0 {
					generate-store($var.local.index, $temp.index, $var.type.size, $out);
				} else {
					my $temp-ptr = $frame.push-temp($var.local.type);
					$out.append(LolOp::ADDI_64);
					append-i16le($out, $temp-ptr.index);
					append-i16le($out, $var.local.index);
					append-u32le($out, $var.offset);
					generate-store($temp-ptr.index, $temp.index, $var.type.size, $out);
					$frame.pop-if-temp($temp-ptr);
				}
				$frame.pop-if-temp($temp);
			} else {
				die "Bad location type '$var'";
			}
		} elsif $statm<expression> {
			my $var = $.compile-expr($frame, $statm<expression>, $out, %aliases);
			$frame.pop-if-temp($var);
		} else {
			die "Bad statement '$statm'";
		}
	}

	method compile-block($frame, $block, Buf $out, %aliases) {
		for $block<statement> -> $statm {
			$.compile-statm($frame, $statm, $out, %aliases);
		}
	}

	method compile-function($func, Buf $out, %aliases) {
		$func.offset = +$out;
		say "  Compiling function {$func.name} @ {$func.offset}...";

		my $frame = StackFrame.new(func => $func);

		my $params-index = 0;
		for $func.formal-params -> $param {
			$params-index -= $param.type.size;
		}

		for $func.formal-params -> $param {
			$frame.vars{$param.name} = LocalLocation.new(
				index => $params-index,
				type => $param.type,
				temp => False,
			);
			$params-index += $param.type.size;
		}

		$.compile-block($frame, $func.body, $out, %aliases);

		$out.append(LolOp::RETURN);
	}

	method compile-functions(Buf $out) {
		if not %.funcs<main>:exists {
			die "Missing main function";
		}

		my $main-func = %.funcs<main>;
		if not ($main-func.return-var.type === %builtin-types<void>) {
			die "Function main must have return type void";
		} elsif +$main-func.formal-params != 0 {
			die "Function main must take no parameters";
		}

		$out.append(LolOp::CALL, 0, 0, 8, 0, 0, 0);
		$out.append(LolOp::HALT);
		$.compile-function($main-func, $out, $main-func.aliases);

		while +@.func-call-fixups > 0 {
			my $fixup = @.func-call-fixups.pop();
			my $func;
			if %.funcs{$fixup.name} {
				$func = %.funcs{$fixup.name};
			} elsif %.materialized-func-templates{$fixup.name} {
				$func = %.materialized-func-templates{$fixup.name};
			} else {
				die "Have func-call-fixup for non-existent function {$fixup.name}"
			}

			if not $func.offset.defined {
				$.compile-function($func, $out, $func.aliases);
			}

			$out.write-uint32($fixup.location, $func.offset);
		}
	}
}

sub MAIN($in-path, $out-path) {
	say "Compiling: $in-path -> $out-path";
	my $cst = Lol.parsefile($in-path);
	if not $cst.defined {
		die "Parse error!";
	}

	my $prog = Program.new();
	$prog.register-defaults();
	$prog.analyze($cst);
	my $out = Buf.new();
	$prog.compile-functions($out);

	my $fh = open $out-path, :w, :bin;
	$fh.write($out);
	$fh.close();

	say "Done.";
}
