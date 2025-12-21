A line

```rexx
    ::class RoutineDoer
    ::method YM
    f = self
    table = .Table~new
    return {use arg a ; return a~(a)} ~ {
        expose f table ; use arg x
        return f ~ { expose x table
                     use arg v
                     r = table[v]
                     if r <> .nil then return r
                     r = x~(x)~(v)
                     table[v] = r
                     return r
                   }
    }
```
Another line

