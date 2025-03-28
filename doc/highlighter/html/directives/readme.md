HTML Highlighter directive test
===============================

-----------------------------------------------------------

A small set of code fragments listing all directives, all directive keywords,
and most forms of keyword variations and combinations.
It can be used to check how the highlighting values work,
and to ensure that all syntactic variants are adequately covered by
the highlighting choices.

See also:

+ [All cases](/rexx-parser/doc/highlighter/html/all/).
+ [All instructions](/rexx-parser/doc/highlighter/html/instructions/).

Directives
----------

#### `ANNOTATE`

```rexx
::Attribute X
::Annotate Attribute X Author Me Date "Yesterday"
::Class C
::Annotate Class C Some Annotation
::Constant K
::Annotate Constant K New "Value"
::Method M
::Annotate Method M Value "23"
::Annotate Package Some Data SomeMore "Data"
::Routine R
::Annotate Routine R This Value
```

#### `ATTRIBUTE`

```rexx
::Class MyClass
::Attribute Name1
::Attribute "Name2"
::Attribute Name3  Get
::Attribute Name4  Set
::Attribute Name5  Class
::Attribute Name6  Class Get
::Attribute Name7  Public
::Attribute Name8  Package
::Attribute Name9  Private
::Attribute Name10 Guarded
::Attribute Name11 Unguarded
::Attribute Name12 Protected
::Attribute Name13 Unprotected
::Attribute Name14 Abstract
::Attribute Name15 Delegate Object
::Attribute Name16 External "Library myLib"
::Attribute Name17 Class Set Package Unguarded Protected
```

#### `CLASS`

```rexx
::Class C1
::Class C2a MetaClass  "Class"
::Class C2b MetaClass   Class
::Class C3  Private
::Class C4  Public
::Class C5a MixinClass "Class"
::Class C5b MixinClass  Class
::Class C6a SubClass   "Class"
::Class C6b SubClass    Class
::Class C7  Abstract
::Class C8  Inherit     Class1 Class2 "Class3"
::Class C9  Private MetaClass Class1 SubClass Class2 Inherit A B C
```

#### `CONSTANT`

```rexx
::Class C
::Constant ONE
::Constant Pi         3.14
::Constant MinusPi  - 3.14
::Constant TwoPi   (PI * 2)
```

#### `METHOD`

```rexx
::Class MyClass
::Method Name1
::Method "Name2"
::Method Name3  Attribute
::Method Name4  Class
::Method Name5  Public
::Method Name6  Package
::Method Name7  Private
::Method Name8  Guarded
::Method Name9  Unguarded
::Method Name10 Protected
::Method Name11 Unprotected
::Method Name12 Abstract
::Method Name13 Delegate Object
::Method Name14 External "Library myLib"
::Method Name15 Class Package Unguarded Protected
```

#### `OPTIONS`

```rexx
::Options
::Options Digits  100
::Options Digits "+ 9"
::Options Digits    9
::Options Form Engineering
::Options Form Scientific
::Options Form Engineering Digits 100
::Options Fuzz      3
::Options Fuzz   "+ 3"
::Options Fuzz      3
::Options All        Condition
::Options All        Syntax
::Options Error      Condition
::Options Error      Syntax
::Options Failure    Condition
::Options Failure    Syntax
::Options LostDigits Condition
::Options LostDigits Syntax
::Options NoString   Condition
::Options NoString   Syntax
::Options NotReady   Condition
::Options NotReady   Syntax
::Options NoValue    Condition
::Options NoValue    Syntax
::Options Prolog
::Options NoProlog
::Options Trace ?
::Options Trace All
::Options Trace ?a
```

#### `REQUIRES`

```rexx
::Requires "some/path/a/program.cls"
::Requires "some/path/another/program.cls" Library
::Requires "some/path/a/third/program.cls" NameSpace Name
```

#### `RESOURCE`

```rexx
::Resource myResource End "The End"
Line 1
Line 2
The End Ignored stuff
```

#### `RESOURCE`

```rexx
::Routine routine1
::Routine routine2 Public
::Routine routine3 Private
::Routine routine4 External "Library myLib"
```