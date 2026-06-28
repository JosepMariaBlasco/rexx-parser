/******************************************************************************/
/*                                                                            */
/* Showcase  --  A standard ooRexx program for syntax-highlighting display    */
/* ========================================================================   */
/*                                                                            */
/* This program is part of the documentation for the Rexx Parser's DocBook    */
/* highlighting toolchain. It is a small but complete, *runnable* ooRexx      */
/* program whose only unusual property is that it deliberately exercises as   */
/* many distinct language constructs as a sensible program can, so that the   */
/* highlighter has something of every kind to colour.                         */
/*                                                                            */
/* It defines a tiny hierarchy of geometric shapes, computes a few of their   */
/* properties, and prints a small report.                                     */
/*                                                                            */
/******************************************************************************/

-- A line comment. Note the running order: the interpreter first tokenises
-- the source, then processes every ::Directive below (building the classes,
-- methods and routines), and only afterwards runs the prologue. That is why
-- the code here can already create .Circle, .Rectangle and the rest -- the
-- classes are fully assembled before the first instruction executes.

Signal On Syntax  Name Trouble
Signal On NoValue Name Trouble

  Numeric Digits 20                     -- widen the default precision a bit

  call Banner "Shape report"

  -- Build a collection of shapes using several literal flavours -------------
  shapes = .Array~new
  shapes~append(.Circle~new(2.5))
  shapes~append(.Rectangle~new(3, 4))
  shapes~append(.Square~new(5))
  shapes~append(.Circle~new("1.0E1"))   -- a number given as a string literal

  total = 0
  Do shape Over shapes
    area = shape~area
    total += area                       -- extended assignment sequence
    Say Left(shape~kind, 12) "area =" Format(area, 6, 4)
  End shape

  Say Copies("-", 32)
  Say Left("TOTAL", 12) "area =" Format(total, 6, 4)
  Say

  -- A classic counted loop with a compound (stem) variable -----------------
  count. = 0
  Do i = 1 To shapes~items
    kind = shapes[i]~kind
    count.kind = count.kind + 1
  End i

  Say "Shape counts:"
  Do kind Over count.~allIndexes~sort
    Say "  "Left(kind, 10) Right(count.kind, 3)
  End

  -- Show a Select, some operators, and the environment symbols --------------
  biggest = LargestOf(shapes)
  If biggest \== .nil Then
    Say "Largest shape is a" biggest~kind "with area" Format(biggest~area, , 4)
  Else
    Say "No shapes to compare."

Exit 0

/*----------------------------------------------------------------------------*/
/* Trouble: a shared condition handler for Syntax and NoValue.                */
/*----------------------------------------------------------------------------*/
Trouble:
  c = Condition("O")
  Say "Caught" c~conditionName "at line" c~position": " c~message
Exit 1

/*============================================================================*/
/* Free-standing routines                                                     */
/*============================================================================*/

/** Print a banner with the given title between two ruled lines.
 *
 * @param  title  The text to display, centred in a field of 32 columns.
 * @return        Nothing useful; called as a subroutine.
 */
Banner: Procedure
  Use Strict Arg title
  rule = Copies("=", 32)
  Say rule
  Say Center(title, 32)
  Say rule
Return

--- Return the shape in `list` having the greatest area.
---
--- @param  list  An Array (or any ordered collection) of Shape instances.
--- @return       The largest Shape, or the Nil object for an empty list.
LargestOf: Procedure
  Use Strict Arg list
  champion = .nil
  Do candidate Over list
    If champion == .nil Then
      champion = candidate
    Else If candidate~area < champion~area Then
      champion = candidate
  End
Return champion

/*============================================================================*/
/* Class hierarchy                                                            */
/*============================================================================*/

/** Shape is the abstract base of the little geometry library. It carries a
 *  human-readable `kind` and promises an `area` to every subclass.
 *
 * @author Showcase
 */
::Class Shape Public Abstract

::Attribute kind get

::Method init
  Expose kind
  Use Strict Arg kind = "shape"

::Method area Abstract                   -- subclasses must override this

::Method describe
  Expose kind
  Return self~kind "with area" self~area

/*----------------------------------------------------------------------------*/

::Class Circle Subclass Shape Public

::Constant Pi 3.14159265358979323846     -- a constant method

::Method init
  Expose radius
  Use Strict Arg radius
  If \radius~isA(.String) | \radius~dataType("Number") Then
    Raise Syntax 93.900 Array ("Circle radius must be numeric, got" radius)
  self~init:super("circle")

::Attribute radius get

::Method area
  Expose radius
  Return self~class~Pi * radius ** 2

/*----------------------------------------------------------------------------*/

::Class Rectangle Subclass Shape Public

::Method init
  Expose width height
  Use Strict Arg width, height
  self~init:super("rectangle")

::Attribute width  get
::Attribute height get

::Method area
  Expose width height
  Return width * height

/*----------------------------------------------------------------------------*/

::Class Square Subclass Rectangle Public

::Method init
  /* A square is just a rectangle with equal sides. */
  Use Strict Arg side
  self~init:super(side, side)
  self~setKind("square")                 -- overrides the inherited kind

::Method setKind
  Expose squareKind
  Use Strict Arg squareKind

::Method kind                            -- override the inherited getter
  Expose squareKind
  If Var("squareKind") Then Return squareKind
  Return "square"