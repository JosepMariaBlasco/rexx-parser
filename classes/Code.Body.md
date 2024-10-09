# The Code.Body class

A Code.Body is a specialized form (a subclass) of Block.Instruction, used to represent clause sequences occuring at the beginning of a program (in the main program or prolog) and
after every directive.

## The implicit exit instruction

Every code body is ended by an implicit exit instruction. The Rexx Parser automatically generated an implicit exit instruction and adds it at the end
of the instruction list composing the body.
