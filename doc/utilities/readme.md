Utilities
=========

----------------------------

All the utilities are located in the `bin` subdirectory.

- [**Elements**](elements/) - A sample utility program
  using the Element API of the Rexx Parser to analyze a program
  and display its list of constituting elements.
- [**Elident**](elident/) - A self-consistency tool that checks
  that a program is identical to the concatenation of the values
  of its parsed element chain.
- [**ERexx**](erexx/) - The Experimental Rexx runner
  transforms programs written in Rexx enhanced with
  [Experimental features](../experimental/), translates them to standard
  ooRexx, and executes them.
- [**Highlight**](highlight/) - A utility program
  that displays a highlighted program.
- [**Identtest**](identtest/) - A self-consistency tool that
  recursively runs the [elident](elident/) and [trident](trident/) tests
  against all Rexx files in a directory tree.
- [**md2html**](md2html/) - A batch utility program
  to transform a set of Markdown files to HTML.
- [**md2pdf**](md2pdf/) - A utility program
  that converts Markdown to print-quality PDF.
- [**RxCheck**](rxcheck/) - A utility program
  that runs the parser with a selectable number of
  early check options enabled.
- [**RxComp**](rxcomp/) - A utility program
  that compares two Rexx files to see if they are equal,
  regardless of casing, line numbers, continuations and comments.
- [**Trident**](trident/) - A self-consistency tool that checks
  that a program is identical to its own parse tree.