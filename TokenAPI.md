# The Token API

There are two main ways to use [the Rexx Parser](TheRexxParser.md): using [the Token API](TokenAPI.md), described here, and using [the Tree API](TreeAPI.md).

To use [the Token API](TokenAPI.md), we will need to make some limited use of the more general [Tree API](TreeAPI.md) first. We will start by [creating an instance](CreatingAnInstance.md) of [the Rexx Parser](TheRexxParser.md) in the usual way, and we will then get its `package`: the `package` method will return a convenient abstraction of the whole parsed program.

```rexx
parser  = .Rexx.Parser~new(file, source)
package = parser~package
```

## The token chain

The returned `package`object will allow us to access a representation of our program as a sequence of tokens, as we will see shortly. We will refer to this sequence of tokens as **the token chain**. We call it a *chain* because our tokens will be doubly-linked: given a certain token `T`, `T~prev` will be the previous token in the chain, and `T~next` will be the next token in the chain.

```
 ... <---> T~prev <---> T <---> t~next <---> ...
```

When `T~prev` is `.Nil`, `T` is the first element of the chain. Similarly, when `T~next` is `.Nil`, `T` is the last element of the chain.

## The prolog and its body

Every package starts with a (possibly empty) *prolog*:

```rexx
prolog = package~prolog
```

A prolog is a form of [code body](CodeBodies.md), that is, a collection of null clauses, labels and instructions delimited by directives, by the program start, or by the program end. 

```rexx
body = prolog~body
```

## Where it all begins

Finally, every high level syntax construct returned by [the Tree API](TreeAPI.md) will have a *begin* token, the place where the construct starts, and a corresponding *end* token.

```rexx
token = token~begin
```

To summarize, we could have written

```rexx
parser  = .Rexx.Parser~new(file, source)
token   = parser~package~prolog~body~begin
```

The `Rexx.Parser` class provides, as a convenience, an equivalent `firstToken` method:

```rexx
parser  = .Rexx.Parser~new(file, source)
token   = parser~firstToken
```

## Iterating over all tokens

That's it! Once we have out first token, we simply have to follow the token chain to iterate over all the program tokens:

```rexx
token   = parser~firstToken
Do Until token == .Nil
  -- Do something with 'token'
  token = token~next
End
```

## Structure of a token

Tokens, of course, have [a certain structure](StructureOfAToken.md). This is covered in detail [in the following chapter](StructureOfAToken.md).