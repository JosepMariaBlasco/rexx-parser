# The Code.Body class

A Code.Body is a specialized form (a subclass) of Block.Instruction, used to represent clause sequences occuring at the beginning of a program (in the main program or prolog) and
after every directive.

## The implicit exit instruction

Every code body is ended by an implicit exit instruction. The Rexx Parser automatically generated an implicit exit instruction and adds it at the end
of the instruction list composing the body.

## Empty bodies

A body is said to be _empty_ when it contains no instructions, besides the implicit exit instruction, and additionally it contains no labels.

## exposed

![Syntax diagram for the exposed method of the Code.Body class](../img/Code.Body.exposed.svg)

Returns a Set of variable names which are exposed by an `EXPOSE` instruction at the beginning of a method. 
The set will be empty in prologs and routine bodies, and when the method does not start by `EXPOSE`.

