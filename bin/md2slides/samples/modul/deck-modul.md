---
rexxpub:
  docclass: slides
  theme: modul
  style: tokio-night
  title: MODUL PoC
  footer:
    presenter: Prof. Rony G. Flatscher
    course: Fundamentals of Computer Science and Programming
    date: today
    license: cc-by-sa
---

# Unit 5 – Programming Part II {#title .title-slide kicker="Procedural and Object-oriented Programming 1"}

Lists · Tuples · for loops · and a real Rexx parser


# Lists {#sec-lists .section}


# Lists {#lists kicker="Sequences"}

- Array (sequence) of elements — ordered and mutable
- `[]` creates a list; access with an index (0-based)
- Insert with `append()` and `insert()`

~~~python
colors = ['blue', 'red', 'green']
colors[1]          # => 'red'
colors.append('orange')
colors.insert(1, 'yellow')
~~~


# Lists vs. Tuples {#lists-vs-tuples .two-col kicker="Sequences" anim=slide}

::: {.col .fragment anim=fade-left}
[List — mutable]{.label}

- Defined with `[]`
- Elements can change
- append, insert, remove

~~~python
colors = ['blue', 'red']
colors.append('green')
~~~
:::

::: {.col .fragment anim=fade-right}
[Tuple — immutable]{.label}

- Defined with `()`
- Elements are fixed
- Less overhead than a list

~~~python
base = ('red', 'blue')
base[0]  # => 'red'
~~~
:::


# for loops {#sec-for .section}


# Example of a for loop {#forloop kicker="Iteration · time-driven build" wait-before=0.9 wait-after=0.7}

- This slide builds itself on a timer — keys override it at any moment

~~~python
lectures = ['Maths', 'English', 'Computer Science']

for lecture in lectures:
    print(f'I love {lecture}')
~~~

[Output:]{.label .fragment anim=fade-up}

~~~output {.fragment anim=blur-in}
I love Maths
I love English
I love Computer Science
~~~


# The Rexx angle {#sec-rexx .section}


# What a real parser can see {#what-the-parser-sees kicker="The Rexx Highlighter"}

~~~rexx
/**
 * This is a doc-comment. The first statement, up to the first period,
 * is the summary, and the rest is the description.
 *
 * @param name Description
 */
::Method open Package Protected         -- Bold, underline, italic
  Expose x pos stem.

  Use Strict Arg name

  a   = 12.34e-56 + " -98.76e+123 "     -- Highlighting of numbers
  len = Length( Stem.12.2a.x.y )        -- A built-in function call
  pos = Pos( "S", "String" )      -- An internal function call
  Call External pos, len, .True         -- An external function call
  .environment~test.2.x = test.2.x      -- Method call, compound variable

  Exit "नमस्ते"G,  "P ≝ 𝔐",  "🦞🍐"     -- Unicode strings
~~~


# Contact {#contact .business-card kicker="Get in touch"}

::: card
Prof. Rony G. Flatscher

Institute for Society and Information Systems

**Email** rony.flatscher@wu.ac.at

**Web** wu.ac.at/en/isis

**Office** Welthandelsplatz 1, D2-C, A-1020 Vienna
:::

::: card
Josep Maria Blasco

Rexx Parser · EPBCN

**Email** josep.maria.blasco@epbcn.com

**Web** rexx.epbcn.com/rexx-parser

**Office** Barcelona
:::
