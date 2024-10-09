# Code bodies

A code body is a sequence of clauses, none of which is a directive. Thus, a body can comprise null clauses, labels and instructions.

Every code body is supposed to be ended by an implicit `EXIT` instruction. The general structure of a program file (a package) is the following:

```ebnf
package      ::= prolog [directive code_body]*
prolog       ::= code_body
code_body    ::= [clause ";"]* implicit_exit_instruction ";"
```

A code body consisting only of comments, null clauses, and the implicit `EXIT` instruction is said to be *empty*. Many directives, like `CONSTANT` or `OPTIONS`, require that the code body following them is empty.

