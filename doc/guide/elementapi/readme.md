The Element API
===============

------------------------------------

Two APIs
--------

The [Rexx Parser](/rexx.parser/) defines two Application Programming Interfaces (APIs)
to manipulate a parsed program, **the Element API**, described here, and
[**the Tree API**](/rexx.parser/doc/guide/treeapi/), described elsewhere.
In some cases, it may be necessary to use both APIs might develop an application,
but fairly sophisticated programs, like [the Rexx Highlighter](/rexx.parser/doc/highlighter/),
can be written by resorting only to the Element API.

Elements
--------

The Element API revolves around a very simple idea:
the Rexx Parser provides a stream or chain of
[**elements**](/rexx.parser/doc/ref/classes/element/),
implemented as a doubly linked list.

When a [Rexx.Parser](/rexx.parser/doc/ref/classes/rexx.parser/) instance is created,
the `firstElement` method can be called to obtain the first element in the stream.
Error handling is considered in [a separate article](/rexx.parser/doc/guide/errors/).

```rexx
parser = .Rexx.Parser~new( name, source )    -- Instantiate a new parser
element  =  parser~firstElement              -- Get the first element
```

One then can progress from a element to the next one in the list
by using the `next` method of the `Element` class.

```rexx
Loop Until element == .Nil                   -- Loop over all elements in the list
  /* Process the element */                  -- Do something with this element
  element = element~next                     -- Get the next element, if it exists
End
```
