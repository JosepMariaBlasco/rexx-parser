The Routine.Directive class
===========================

--------------------------

The Routine.Directive class creates objects which
represent the `::ROUTINE` directives of an ooRexx program.

Superclass: [Rexx.Directive](../)

Methods of the Routine.Directive class
--------------------------------------

### name

![name](Routine.Directive.name.svg) \

Returns the name of the routine, as a string element or a symbol element.

### private

![private](Routine.Directive.private.svg) \

Returns `1` when the routine is private, otherwise returns `0`.
Routines are private by default; the `PUBLIC` keyword on the
`::ROUTINE` directive makes them public.

### external

![external](Routine.Directive.external.svg) \

Returns a string containing the _spec_ that identifies the routine
in an external library, or `.Nil` if the routine is not external.

### body

![body](Routine.Directive.body.svg) \

Returns the Code.Body object associated to this directive,
or `.Nil` if the routine is external.

### routine

![routine](Routine.Directive.routine.svg) \

Gets or sets the Rexx.Routine object associated to this directive.