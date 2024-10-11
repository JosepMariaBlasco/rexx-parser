# The Token API

There are two main ways to use [the Rexx Parser](ReadMe.md): using [the Token API](TokenAPI.md), described here, and using [the Tree API](TreeAPI.md).

To use [the Token API](TokenAPI.md), we will need to [create an instance](CreatingAnInstance.md) of [the Rexx Parser](ReadMe.md). We will then get its _first token_ using the `firstToken` method .

```rexx
parser = .Rexx.Parser~new(file, source)
token  = parser~firstToken
```

## The token chain

This token will be the starting extreme of doubly-linked chain, the token chain. Given a token `T`, `T~prev` will be the previous token in the chain, and `T~next` will be the next token in the chain.

```
 ... <---> T~prev <---> T <---> t~next <---> ...
```

`T~prev` will be `.Nil` for the first token in the chain, and `T~next` will be `.Nil` for the last token in the chain.

## Iterating over all tokens

That's it! Once we have out first token, we simply have to follow the token chain to iterate over all the program tokens:

```rexx
parser = .Rexx.Parser~new(file, source)
token  = parser~firstToken
Do Until token == .Nil
  -- Do something with 'token'
  token = token~next
End
```

## Structure of a token

Tokens, of course, have [a certain structure](Token.md). This is covered in detail [in the corresponding chapter](Token.md).
