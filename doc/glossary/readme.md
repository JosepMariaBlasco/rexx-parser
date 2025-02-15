Glossary
========

--------------------------

This small glossary should be taken as a
complement to the excellent indexes that can
be found in the various official Rexx manuals.
It aims to contain:

a. Definitions for *new* terms which we are introducing.
   For example, *element*, or *style patch*.
b. Definitions for terms which are *used* in the
   Rexx literature, but *not formally defined*.
   For example, the current (5.0) version of
   the ooRexx Reference *uses* the term "code body"
   in several places, but there is no formal definition
   of what a code body is.

Contents
--------

- [Code body](#code-body)
- [Element](#element)
  + [Category](#element-category)
  + [Ignorable](#ignorable-element)
  + [Inserted](#inserted-element)
  + [Marker](#marker-element)
  + [Zero-length](#zero-length-element)
- [Element chain](#element-chain)
- [Element category](#category)
- [Element stream](#element-stream)
- [Ignorable element](#ignorable-element)
- [Implied element](#implied-element)
- [Inserted element](#inserted-element)
- [Marker (or marker element)](#marker-element)
- [Taken constant](#taken-constant)
- [Zero-length element](#zero-length-element)

#### Code body

A **code body** is a sequence of clauses,
none of which is a directive.
Thus, a code body can comprise null clauses,
labels and instructions.

Every code body is supposed to be ended by an
implicit `EXIT` instruction. Thus, the general structure
of a program file (a package) is the following:

~~~ebnf
program   ::= prolog (directive code_body)*
prolog    ::= code_body
code_body ::= (clause ";")* implicit_exit_instruction ";"
~~~

A code body can be:

1. the *prolog of a package*,
2. the *body of a method*, or
3. the *body of a `::ROUTINE`*.

A code body consisting only of comments, null clauses,
and the implicit `EXIT` instruction is said to be *empty*.
Many directives, like `CONSTANT` or `OPTIONS`,
require that the code body following them is empty.

#### Element

In the context of the Rexx Parser, an **element**,
is any of the elements returned by the tokenizer.
This includes standard Rexx tokens, but also
other elements found while parsing that are not
tokens, like whitespace and comments.

Our definition of "element" has the following,
interesting, property:

> A program is identical to the ordered concatenation
> of all its elements.

(Please note that the Rexx definition of "token"
does not have this property: whitespace and comments would be
lost.)

Elements may be special markers *inserted*
by the parsing process, or [*ignorable*](#ignorable-element),
when they can be safely ignored.

#### Element category

Every element has its **category**, a one-byte value
that determines its syntactic category.

#### Element chain

When a program is parsed, the Rexx Parser builds
an ordered collection of element called **the Element chain**.
This is a doubly-linked chain, traversable using the
`next` and `prev` methods of an element instance.

- If `E` is an element, then `E~next` is the next element in the chain,
  unless `E` is the last element in the chain, in which case
  `E~next == .Nil`.
- If `E` is an element, then `E~prev` is the previous element in the chain,
  unless `E` is the first element in the chain, in which case
  `E~prev == .Nil`.

If `parser` is a `Rexx.Parser` object, then `parser~firstElement`
returns the first element in the element chain.

#### Element stream

Another name for [the element chain](#element-chain).

#### Ignorable element

An **ignorable element** may act as a separator,
but otherwise it adds nothing to the
(non-reflective) semantics of a program.

Comments are always ignorable. Whitespace is
ignorable in many cases, but in some cases it is
not ignorable, since it represents a special form of
concatenation.

#### Implied element

Another name for an [inserted element](#inserted-element).

#### Inserted element

An **inserted element** is a special marker generated
by [the Rexx Parser](/rexx.parser/).

Some of these markers are part of the Rexx language definition.
For example, the Rexx language assumes a semicolon after an `ELSE`,
an `OTHERWISE` or a `THEN` clause, or before a `THEN`
clause, as an aid that greatly improves the writability
of Rexx programs. [The Rexx Parser](/rexx.parser/) automatically
*inserts* these semicolons, and returns the corresponding
*inserted elements*.

Some other markers are created by [the Rexx Parser](/rexx.parser/) as
a way to ensure that certain invariants are met. For example,
a dummy end-of-clause marker is inserted at the beginning
of the parser program; this additional marker allows us
to ensure that the following invariant is true:
*all clauses are always encloses between
two end-of-clause markers*.

#### Marker (or marker element) {#marker-element}

Another name for an [inserted element](#inserted-element).

#### Taken constant

A **taken constant** is a normal, non-ignorable, element which,
by virtue of its syntactic role, is expected to be either
a string or a symbol which is taken as a constant. Well-known
examples are labels, or procedure names in a `CALL` instruction,
which are taken at face value, i.e., without substituting them
for the value of a possible variable, if one exists with the same name.

"Taken constant" is an unfortunate name. It can be found as item
6.3.2.22 in the syntax definitions of the ANSI standard, and it is
being used for lack of a standard (and decent) denomination.

#### Zero-length element {#zero-length-element}

Another name for an [inserted element](#inserted-element).
