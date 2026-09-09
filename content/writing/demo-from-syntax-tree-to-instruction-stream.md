---
title: "From Syntax Tree to Instruction Stream"
date: 2026-09-09
slug: "from-syntax-tree-to-instruction-stream"
demo: true
toc: true
series:
  label: "Demo series"
  before: "This original test article takes structural cues from"
  link_label: "Zig AstGen: AST => ZIR"
  url: "https://mitchellh.com/zig/astgen"
  after: "It is demo content, not a reproduction of that post, and can be removed with the other demo files."
---

A parser can tell us that a program contains a declaration, a call, and an
addition. That is useful, but it is still too close to punctuation for later
compiler passes. Before analysis becomes comfortable, the tree needs to become
a sequence of explicit instructions.

This article builds a tiny lowering pass for a made-up expression language. The
examples use Zig syntax for the implementation, while the instruction stream is
deliberately small enough to inspect by hand.

## The problem between parsing and analysis

Consider a source expression with one local binding:

```text
let total = price + tax
emit(total)
```

The parser preserves the shape that the author typed. An abbreviated syntax
tree might look like this:

```text
file
├─ let_decl "total"
│  └─ binary "+"
│     ├─ identifier "price"
│     └─ identifier "tax"
└─ call "emit"
   └─ identifier "total"
```

Trees are pleasant for syntax. They are less pleasant for questions such as
“which instruction defines this value?” or “does this name exist at this point
in the program?” An instruction stream gives every intermediate result an
identity and makes evaluation order visible.

### What the output looks like

For the source above, our lowering pass will emit:

```text
%0 = load_name "price"
%1 = load_name "tax"
%2 = add %0, %1
     bind "total", %2
%3 = load_name "total"
%4 = call "emit", [%3]
     finish
```

The percent-prefixed values are references. `bind` and `finish` do not produce
values, so they have no result number. This modest convention is enough to let
later stages walk a flat list without forgetting where each value came from.

## A deliberately small instruction model

We only need a handful of operations to explore the mechanics:

```zig
const Op = enum {
    integer,
    load_name,
    add,
    bind,
    call,
    finish,
};

const Ref = u32;

const Instruction = struct {
    op: Op,
    a: u32 = 0,
    b: u32 = 0,
};
```

The fields `a` and `b` are intentionally vague. Small fixed-width instructions
are easy to store and iterate, but complex operations cannot fit all of their
data inline. We will give those operations a side table later.

### Opcodes are contracts

An opcode is not merely a label in an enum. It defines how every field must be
read. In this example:

- `integer` stores an immediate number in `a`.
- `add` treats `a` and `b` as references to earlier instructions.
- `load_name` treats `a` as an index into an interned string table.
- `call` treats `a` as a string index and `b` as an index into extra data.

That interpretation should live in one documented place. If the writer and
reader disagree about a field, the stream remains valid bytes while becoming a
wrong program—the most annoying kind of compiler bug.

### Values and effect-only instructions

Our `Ref` is just an index into the instruction array. That works for value
producers but not for operations like `bind`. Rather than inventing a fake
value, the builder returns an optional reference:

```zig
fn append(builder: *Builder, instruction: Instruction) !?Ref {
    const index: Ref = @intCast(builder.instructions.items.len);
    try builder.instructions.append(builder.allocator, instruction);

    return switch (instruction.op) {
        .bind, .finish => null,
        else => index,
    };
}
```

The type forces the lowering code to acknowledge the distinction. It also
prevents an effect-only operation from accidentally becoming an operand.

## The lowering context

Lowering carries more state than a recursive `switch` initially suggests. Our
builder owns four collections:

1. emitted instructions;
2. extra operand data;
3. interned strings;
4. lexical scopes and their bindings.

```zig
const Builder = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayListUnmanaged(Instruction) = .empty,
    extra: std.ArrayListUnmanaged(u32) = .empty,
    strings: StringInterner,
    scope: *Scope,
};
```

Keeping this state together gives every lowering function the same vocabulary.
It also creates a natural boundary: parsing owns source shape, while the builder
owns instruction identity and semantic bookkeeping.

### String interning

Names appear repeatedly. Storing `"total"` beside every use would make
instructions variable-sized and comparisons needlessly expensive. The interner
stores the text once and returns a compact integer key.

Interning does **not** resolve the name. It only establishes that two equal
spellings share one key. Scope lookup remains a separate step because identical
text can refer to different bindings in nested blocks.

### Scope frames

Each scope points to its parent and maps string keys to definitions:

```zig
const Scope = struct {
    parent: ?*Scope,
    bindings: std.AutoHashMapUnmanaged(u32, Ref),

    fn lookup(scope: *const Scope, name: u32) ?Ref {
        var current: ?*const Scope = scope;
        while (current) |frame| : (current = frame.parent) {
            if (frame.bindings.get(name)) |value| return value;
        }
        return null;
    }
};
```

The loop makes shadowing explicit: the nearest frame wins. It also keeps name
resolution out of the generic instruction-emission path.

{{< notice type="note" label="Note" >}}
This demo resolves locals during lowering to keep the example compact. A real
compiler may preserve unresolved names for a later pass, especially when module
imports, overload sets, or incremental compilation affect lookup.
{{< /notice >}}

## Result locations

An expression usually produces a value, but its destination can change how we
generate that value. A call argument needs a temporary reference. An assignment
already has a destination. A discarded expression may only need its effects.

We can describe those possibilities directly:

```zig
const ResultLoc = union(enum) {
    value,
    discard,
    assign_to: Ref,
};
```

Passing a result location downward avoids emitting a temporary and then copying
it in a second step. More importantly, it lets the caller state its intent
before the child expression is lowered.

### Why context changes generation

Suppose `buffer()` constructs a large value. In value context it may return a
new temporary. In assignment context it can initialize the target directly. In
discard context, the compiler must preserve calls with side effects but may omit
the final materialized value.

The syntax tree is identical in all three cases. Only the surrounding context
reveals the correct instruction shape.

## Lowering one expression

With the pieces in place, the central function becomes a dispatcher. Every node
kind receives a requested result location and either returns a reference or
reports that no value was required.

```zig
fn lowerExpr(builder: *Builder, node: Node.Index, result: ResultLoc) !?Ref {
    return switch (builder.tree.tag(node)) {
        .integer_literal => builder.lowerInteger(node, result),
        .identifier => builder.lowerIdentifier(node, result),
        .add => builder.lowerAdd(node, result),
        .call => builder.lowerCall(node, result),
        else => error.UnsupportedSyntax,
    };
}
```

### Integer literals

An integer is the simplest value-producing node. Parse its token, append an
instruction, and adapt the result to its destination:

```zig
fn lowerInteger(builder: *Builder, node: Node.Index, result: ResultLoc) !?Ref {
    const token = builder.tree.mainToken(node);
    const value = try std.fmt.parseInt(u32, builder.tree.tokenSlice(token), 10);
    const ref = (try builder.append(.{ .op = .integer, .a = value })).?;
    return builder.place(ref, result);
}
```

The final `place` operation is shared by every value producer. It may return the
reference, emit an assignment, or discard it.

### Addition

Binary addition demonstrates evaluation order. Lower the left operand, then the
right, then emit the instruction that consumes both:

```zig
fn lowerAdd(builder: *Builder, node: Node.Index, result: ResultLoc) !?Ref {
    const pair = builder.tree.binaryOperands(node);
    const lhs = (try builder.lowerExpr(pair.left, .value)).?;
    const rhs = (try builder.lowerExpr(pair.right, .value)).?;
    const sum = (try builder.append(.{ .op = .add, .a = lhs, .b = rhs })).?;
    return builder.place(sum, result);
}
```

Reversing those first two calls may be observable if operands contain function
calls. Even a tiny intermediate representation must therefore define order,
not merely arithmetic.

### Assignment

Assignment is different because the left side names a destination rather than
producing an ordinary value. We resolve that destination first and pass it into
the right side:

```zig
fn lowerAssignment(builder: *Builder, node: Node.Index) !void {
    const pair = builder.tree.assignmentOperands(node);
    const name = try builder.internNodeName(pair.left);
    const target = builder.scope.lookup(name) orelse return error.UnknownName;
    _ = try builder.lowerExpr(pair.right, .{ .assign_to = target });
}
```

This is why result locations deserve a real type. Without one, assignment
becomes a special case scattered through every expression generator.

## Variable-length operands

A call can have zero, one, or many arguments. The fixed instruction has room
for neither the list nor its length, so `extra` stores a compact record:

```text
extra index 12
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ arg_count: 3 │ arg_ref: %4  │ arg_ref: %7  │ arg_ref: %9  │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

The `call` instruction stores `12` in field `b`. A reader begins there, reads
the count, and then consumes exactly that many references.

### Appending a call record

The builder should append the complete record before it emits the call:

```zig
fn appendCallData(builder: *Builder, args: []const Ref) !u32 {
    const start: u32 = @intCast(builder.extra.items.len);
    try builder.extra.append(builder.allocator, @intCast(args.len));
    try builder.extra.appendSlice(builder.allocator, args);
    return start;
}
```

The order matters for error handling. If allocation fails halfway through, the
builder can truncate `extra` back to `start`; no instruction points at partial
data yet.

## Diagnostics without losing the source

Flat instructions are convenient, but error messages still need source
locations. A parallel array can associate each instruction with the token or
node that produced it:

```zig
try builder.instructions.append(allocator, instruction);
try builder.origins.append(allocator, .{ .node = node, .token = main_token });
```

Parallel arrays are safe only when appended and truncated together. Another
reasonable design stores the origin inside the instruction. The right choice
depends on whether every later pass needs locations or only diagnostic paths do.

### Recovering after an error

For an editor, returning after the first unknown name is not enough. A recovery
strategy can emit an `invalid` placeholder reference, record a diagnostic, and
continue until a statement boundary. Later passes must recognize the placeholder
and avoid producing duplicate errors.

Recovery is a policy decision, not a free robustness upgrade. Batch compilers
may prefer an immediate failure; interactive tools often benefit from several
useful diagnostics per run.

## Completing the stream

At the end of a file, the builder verifies its invariants before appending
`finish`:

- every referenced instruction index exists;
- every extra-data record ends within the side table;
- all temporary scopes have been popped;
- the instruction and origin arrays have equal lengths.

These checks turn quiet corruption into a local failure. They are especially
valuable while the instruction set is changing.

```text
instructions: 18
value results: 11
extra words:   9
string keys:   4
scopes open:   1 (root)
status:        valid
```

## Reading the result

The final stream is not machine code, and it does not need to be. Its job is to
replace syntax-shaped questions with explicit operations and references. Later
passes can attach types, fold constants, report unresolved names, or choose a
machine-oriented representation.

The useful boundary is conceptual:

1. the syntax tree remembers how the program was written;
2. lowering records what must happen and in what order;
3. analysis decides whether those operations are meaningful;
4. code generation decides how the meaningful operations run.

That separation is the real payoff. The instruction format may evolve, but each
stage still has one kind of question to answer.

## A compact debugging checklist

When a lowering bug produces a surprising stream, inspect it in this order:

1. Confirm the parser assigned the expected node kind.
2. Confirm child expressions were visited in language-defined order.
3. Check whether the requested result location was preserved.
4. Resolve every reference back to the instruction that created it.
5. Decode extra data using the opcode's documented layout.
6. Compare scope entry and exit around the failing node.
7. Verify the origin map still points to the intended source token.

Small textual dumps make this process unusually effective. If an intermediate
form cannot be printed and read, it is much harder to trust.
