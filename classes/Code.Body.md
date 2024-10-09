# The Code.Body class

A Code.Body is a specialized form (a subclass) of Block.Instruction, used to represent clause sequences occuring at the beginning of a program (in the main program or prolog) and
after every directive.

## The implicit EXIT instruction

Every code body is ended by an implicit `EXIT` instruction. The Rexx Parser automatically generated an implicit `EXIT` instruction and adds it at the end
of the instruction list composing the body.

## Empty bodies

A body is said to be _empty_ when it contains no instructions, besides the implicit `EXIT` instruction, and additionally it contains no labels.

__Note__: A label at the end of a body is indeed attached to the implicit `EXIT` instruction and identifies it. For example, in the following code,

```rexx
  Do Forever
    /* Do something      */
  If condition Then Signal Done
    /* Do something else */
  End

Done:
::Requires "whatever"
```

when control is transferred to the `Done` label, the body is immediately exited.

## exposed

![Syntax diagram for the exposed method of the Code.Body class](../img/Code.Body.exposed.svg)

Returns a Set of variable names which are exposed by an `EXPOSE` instruction at the beginning of a method body. 
The set will be empty in prologs and `::ROUTINE` bodies, and when the method does not start by `EXPOSE`.

See also method [useLocal](#useLocal).

## instructions

![Syntax diagram for the instructions method of the Code.Body class](../img/Code.Body.instructions.svg)

Returns an Array of instructions composing the code body. Please note that the Array will always have at least one
element, namely, [the implicit `EXIT` instruction](#The-implicit-EXIT-instruction)

## labels

![Syntax diagram for the labels method of the Code.Body class](../img/Code.Body.labels.svg)

Returns an Array containing all the label clauses found in the code body, in their order of appearance.

## useLocal

![Syntax diagram for the useLocal method of the Code.Body class](../img/Code.Body.useLocal.svg)

Returns a possibly empty Set of variable names which are specified in a `USE LOCAL` instruction at the beginning of a method body,
or `.Nil` if no `USE LOCAL` instruction was present, or the code body is a prolog or a `::ROUTINE` body.
