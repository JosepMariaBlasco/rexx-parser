# The Rexx Parser

The Rexx Parser is a sophisticated tokenizer and a full Abstract Syntax Tree parser 
for Rexx and Open Object Rexx (ooRexx). The parser offers two different APIs to access a parsed program:

* [The Token API](TokenAPI.md) returns a doubly linked chain of [tokens](Token.md).
  The returned tokens include proper Rexx tokens and other non-token elements, like comments
  and non-significant blanks. Tokens have a very simple structure but, at the same time,
  they convey a lot of information, since the parser annotates each token with a very
  detailed syntactic category marker. For example, a variable can be a normal (i.e.,
  local) variable, an instance variable (EXPOSEd in an instance method), or a class
  variable (EXPOSEd in a class method). In many places, the syntax of Rexx and ooRexx
  require a string value, or a symbol that "is taken as a constant". The parser
  annotates these tokens with an additional attribute, which allows to differentiate,
  for example, between a ROUTINE name, a METHOD name or a label.

* [The Tree API](TreeAPI.md) returns a single object, a [Rexx.Package](classes/Rexx.Package.md),
  which is the top of a full Abstract Syntax Tree representation of the parsed program.
  The returned package can be traversed following the structure of the source code (e.g.,
  there is an API that returns the different directives found in the program in the
  source code order, then an API which returns the list of instructions, if any, that
  conform the directive body, and so on), or it can be accessed by categories: for example,
  you can retrieve a StringTable containing all the classes present in the source,
  or all the routines, etc.

The Rexx Parser was written by Josep Maria Blasco Comellas <josep.maria.blasco@epbcn.com>,
and is distributed under an [Apache license](LICENSE).
