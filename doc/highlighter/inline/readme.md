# Highlighting Inline Code

## Code blocks and code spans

[CommonMark](https://commonmark.org/), as determined by its spec, <https://spec.commonmark.org/0.31.2/>,
defines [fenced code blocks](https://spec.commonmark.org/0.31.2/#fenced-code-blocks)
and [code spans](https://spec.commonmark.org/0.31.2/#code-spans). 
Roughly speaking, code blocks are displayed as blocks, and code spans
are displayed inline, inside prose (for example, in the middle of a technical explanation).
Still speaking in an approximate way, in HTML terms, a code block is more 
like a `<div>` (probably with `<pre>` and
`<code>`) and a code span is more like a `<span>`.

CommonMark also defines *info strings*, which are optional parts of code blocks: 
"The line with the opening code fence may 
optionally contain some text following the code fence; this is trimmed of leading 
and trailing spaces or tabs and called the info string." 
"The first word of the info string is typically used to specify the language of the code sample, 
and rendered in the class attribute of the code tag. However, this spec does not mandate any 
particular treatment of the info string."
An info string, thus, does not
determine how a code block will be displayed by Markdown: this is left to the renderer.

Many Markdown implementations use these info strings, in a more or less standardized
way, to allow document authors to indicate their highlighting preferences.
When a piece of code is, say, a Python program, one writes
````
```python
(python code)
```
````
and, if the renderer includes support for Python highlighting, your program
is nicely highlighted. This is the mechanism the Rexx Highlighter itself uses
to highlight Rexx fenced code blocks.

The `` ```languageName `` syntax is sugar for `` ```{.languagename} ``,
and you normally can specify several additional options inside the braces.
For example, if you are using Pandoc Markdown, `` ```{.cpp .numberLines} ``
produces a numbered C++ program listing.

Now. CommonMark *does not define* anything equivalent to info strings for code
spans. This means that you *cannot* tag your code span, and, consequently,
that you *cannot* say "this code span is Python code". This is a real nuisance,
and several solutions have been proposed to overcome that problem.

Some environments allow authors to say "all the code spans are" (say) "Python code".
This is very convenient, as it allows one to continue using perfectly standard
Markdown code while having code spans highlighted, 
but as a general solution it presents obvious difficulties
when dealing with multi-language spans.

Other environments, like Pandoc, define certain *extensions* to the Markdown
syntax that allow the specification of certain form tags associated with
a code span. For example, Markdown Pandoc allows one to write `` `(some python code)`{.python} ``
and this will be translated to `<code class="python">(tagged python code)</code>`
when requesting HTML output: the original Python code has been tagged by 
[*skylighting*](https://github.com/jgm/skylighting), 
a Haskell highlighter library that comes with Pandoc.

Pandoc Markdown also allows writing extra attributes after the language tag:
`` `some C++ code`{.cpp extra-attributes} ``. 

Inline code highlighting support in the Rexx Highlighter takes the tagged code span idea
and tries to adapt it to the (oo)Rexx world.

## What's the need for highlighted code spans?

If, as it often happens, code blocks are highlighted, and code spans are not,
you lose a lot of information. Consider this block of Rexx code:

```rexx
/* Squares its only argument */
Use Arg x
Return x**2
```

We can now say that beginning a program with a short comment that describes
its function is good practice. We could also have said that `/* a short comment */`
at the beginning is good practice. Or that `/* a short comment */`{.rexx}
is good practice. We can say that Rexx does not have reserved keywords,
so that a variable can be called `If`, or `End`. We could also have said that
a variable can be called `If`{.rexx variable} or `End`{.rexx variable}.
And we could even add that the variable `End`{.rexx variable} is
not the same as the keyword `End`{.rexx}.

Here. Quote, "And we could even add that the variable `End`{.rexx variable} is
not the same as the keyword `End`{.rexx}.", unquote. *You simply cannot*
*read this sentence without a coloring scheme that styles variables*
*and keywords differently.*

## The Rexx difference

Most languages have a list of reserved keywords; you simply cannot create variables,
classes, functions, etc., that bear any of these keywords as names. This is done
*to simplify the life of tool writers, not of users*: writing a compiler or an
interpreter for a language is much, much easier when the language has
reserved keywords. There even are automated tools that help you to write
a parser from a grammar.

Unfortunately this does not help users in any particular way. When I am working
on a certain problem, it's very likely that I'll have to deal with things that
have a `start`{.rexx} and an `end`{.rexx variable}. But the string `"end"`,
as we well know, can also work as a keyword -- for example, when closing a `Loop`{.rexx}
or a `Select`{.rexx} instruction. The Rexx Highlighter always knows
how to highlight a certain element or token, *because it has access
to the whole program*. When Rexx finds a `Call myRoutine`{.rexx} instruction,
*it can not know whether this is an internal call, an external call,
a `::Routine`{.rexx} call, etc., without potentially
having to scan first the totality of the program*.

Now: what is "the totality of the program" when we are highlighting
a code span? The span can be very small -- it usually will consist
of a single element or token. In a surprisingly high number of cases, 
a single token _can_ be correctly highlighted by the Highlighter.
A string, for example, can be taken to be a complete program by itself:
a string is a term, a term is an expression, and an instruction consisting
of an expression is... a command instruction. Thus, a program may consist
of a single string, and, as the Highlighter knows how to style a program,
and therefore `` `"string"`{.rexx} `` is trivial to highlight; indeed,
the Highlighter highlights it as if it were
````
```rexx
"string"
```
````
and that's it. A similar reasoning can be applied to numbers,
environment symbols, simple variable symbols which are not instruction keywords,
stems, compound variables, and constant symbols.

Now consider `` `If`{.rexx} ``. How should the Highlighter style it? `"If"` may
be an identifier or a keyword, and the Highlighter simply cannot know what
is the state of things, because _it does not have enough context_. In these cases,
we will have to help the highlighter by providing the information that is
missing, by adding modifiers to the `.rexx` tag: `` `If`{.rexx variable} `` 
will indicate that `If`{.rexx variable} is a variable.

## Inline Rexx tags

### Keywords, subkeywords, and keywords-as-variables

Rexx keywords are automatically recognized as such: `Do`{.rexx}.

| Tag                        | For                                       |
|----------------------------|-------------------------------------------|
| `rexx subkeyword`          | `To`{.rexx subkeyword}, `By`{.rexx subkeyword}, `Until`{.rexx subkeyword}, `While`{.rexx subkeyword}…             |
| `rexx directive keyword`   | the directive keyword alone (`Method`{.rexx directive-keyword})    |
| `rexx directive subkeyword`| `Public`{.rexx directive subkeyword}, `Subclass`{.rexx directive subkeyword}, `Private`{.rexx directive subkeyword}, `Inherit`{.rexx directive subkeyword}|
| `rexx variable`            | a simple variable, like `Select`{.rexx variable}, which is also an instruction keyword |
| `rexx exposed`             | exposed `variable`{.rexx exposed}, `stem.`{.rexx exposed} or `compound.var`{.rexx exposed} |

When you want to use the name of a keyword instruction as a variable name
(and this also includes `THEN`{.rexx variable},
`ELSE`{.rexx variable}, `WHEN`{.rexx variable}, `OTHERWISE`{.rexx variable} or
`END`{.rexx variable}, which start clauses), you have to be explicit
about it and use the appropriate tag `{.rexx variable}`, so that the Parser
doesn't get confused: `Parse`{.rexx} is the start of
an incomplete instruction, while `Parse`{.rexx variable} is a
viable variable name.


### Names (and some delimiters and values)

| Public tag               | For                               |
|--------------------------|-----------------------------------|
| `rexx class`             | `::Class`{.rexx directive} `name`{.rexx class}                  |
| `rexx constant value`    | `::Constant`{.rexx directive} `constantName`{.rexx method} `constantValue`{.rexx constant value}                |
| `rexx method`            | `::Method`{.rexx directive} `name`{.rexx method}                  |
| `rexx requires`          | `::Requires`{.rexx directive} `name`{.rexx requires} |
| `rexx resource`          | `::Resource`{.rexx directive} `name`{.rexx resource}                     |
| `rexx resource delimiter`| `::Resource`{.rexx directive} `name`{.rexx resource} `End`{.rexx directive subkeyword} `delimiter`{.rexx resource delimiter}                |
| `rexx routine`           | `::Routine`{.rexx directive} `name`{.rexx routine}                  |
| `rexx label`             | label (`end:`{.rexx} → "the `end`{.rexx label} label") |
| `rexx namespace`         | `namespace`{.rexx directive subkeyword} `name`{.rexx namespace}                    |
| `rexx annotation`        | `::Annotate`{.rexx directive} `class`{.rexx directive subkeyword} `MyClass`{.rexx class} `myName`{.rexx annotation} ...                   |
| `rexx annotation value`  | ... `"myValue"`{.rexx annotation value}                  |
| `rexx argument`          | Argument names: `index`{.rexx argument} (Executor only)                 |
| `rexx block`             | `Label`{.rexx subkeyword} `name`{.rexx block} (in `Do`{.rexx keyword}, `Loop`{.rexx keyword} and `Select`{.rexx keyword}) |
| `rexx environment`       | `.environment`{.rexx environment} variable name                  |
| `rexx user condition`    | `UserCondition`{.rexx user condition}|


### Calls


| Function form                    | Subroutine form                    | Shortcut (= subroutine)  |
|----------------------------------|------------------------------------|--------------------------|
| `rexx internal function`         | `rexx internal subroutine`         | `rexx internal`          |
| `rexx builtin function`          | `rexx builtin subroutine`          | `rexx builtin`           |
| `rexx package function`          | `rexx package subroutine`          | `rexx package`           |
| `rexx external function`         | `rexx external subroutine`         | `rexx external`          |
| `rexx external package function` | `rexx external package subroutine` | `rexx external package`  |


### Expressions

If you want to highlight a sequence like `x = y`{.rexx expression} _and stress the fact
that this is a comparison_ (i.e., that it is _not_ an assignment, `x = y`{.rexx}), you
can use the `expression` modifier, which takes care to ensure that the `=`{.rexx comparison}
sign is highlighted as a comparison operator.

### Operators and special characters

If you need to highlight an operator or a special character, you simply tag it as usual:
for example, `` `+`{.rexx} `` is the Rexx infix addition operator, `+`{.rexx},
and `` `:`{.rexx} `` is the colon special character, `:`{.rexx}.
This works for single- and multi-character operators, like `<<=`{.rexx}.
Only some few cases are ambiguous:

+ Infix `+`{.rexx} and `-`{.rexx} vs prefix `+`{.rexx prefix} and
  `-`{.rexx prefix}. By default, `{.rexx}` highlights the Operators
  as infix operators; use the `prefix` modifier to highlight prefix
  operators, like in `` `+`{.rexx prefix} ``.
+ Standard comparison operators `<`{.rexx} and `>`{.rexx} vs. variable 
  reference marks, `<`{.rexx reference} and `>`{.rexx reference}:
  please use the `reference` modifier.
+ The equals `"="` sign is a special case, as there is no default
  to preserve: in some cases, it works as an assignment operator, and
  in some other cases, as a comparison operator, and there is no sane
  default to choose. When you want to highlight the equals sign alone,
  please use one of `assignment` (`=`{.rexx assignment})
  or `comparison` (`=`{.rexx comparison}) as modifiers, to make your
  meaning explicit.
* If you need to highlight a blank as a blank concatenation operator,
  use the `blank-concatenation` modifier.
