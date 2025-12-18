/******************************************************************************/
/*                                                                            */
/* Elements.cls                                                               */
/* ============                                                               */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20251206    0.3a Split Scanner.cls in two, move all classes here           */
/*                                                                            */
/******************************************************************************/

 .environment ~                     Element =                     .Element
 .environment ~               Error.Element =               .Error.Element
 .environment ~            Inserted.Element =            .Inserted.Element
 .environment ~          Inserted.Semicolon =          .Inserted.Semicolon
 .environment ~                Line.Comment =                .Line.Comment
 .environment ~ Operator.Character.Sequence = .Operator.Character.Sequence
 .environment ~               Resource.Data =               .Resource.Data
 .environment ~            Standard.Comment =            .Standard.Comment
 .environment ~  Special.Character.Sequence =  .Special.Character.Sequence
 .environment ~              Symbol.Element =              .Symbol.Element
 .environment ~      StringOrSymbol.Element =      .StringOrSymbol.Element
 .environment ~      Tail.Separator.Element =      .Tail.Separator.Element
 .environment ~          WhiteSpace.Element =          .WhiteSpace.Element

::Requires "Globals.cls"

/******************************************************************************/
/******************************************************************************/
/* The ELEMENT class                                                          */
/******************************************************************************/
/******************************************************************************/

::Class Element Public -- SubClass Directory

-- Elements are stored in a doubly-linked list

::Attribute next
::Attribute prev

-- remove -- Remove an element from the chain by unlinking it
-- The element must not be the head or the tail of the chain (not checked)

::Method remove
  self~next~prev = self~prev
  self~prev~next = self~next

-- Every element has a starting ("from") and an ending position ("to").

::Attribute from
::Attribute to

-- Every element has a value and a source, which may be identical or not.
-- The source is generally the element as it appears in the source file
-- The value is interpreted. For example, symbols are uppercased,
-- strings have double quotes removed, etc.

::Attribute source
::Attribute value

-- All elements have a category, and, additionally, taken constants have a
-- subcategory. Categories and subcategories are defined in Globals.cls.

::Attribute category
::Attribute subCategory

-- Parentheses, brackets and braces are paired
-- We also use this attribute to store the end of a ::RESOURCE in the
-- directive marker "::".

::Attribute closing

-- Shebangs, comments, and some form of whitespace can be ignored (but may
-- act as separators)

::Attribute ignorable

-- When a variable starts a term that is being assigned a value,
-- in assignment instructions, but also in some other contexts, like
-- PARSE or USE ARG instructions, we mark is as "assigned".

::Attribute assigned

-- An approximate value. It is used to determine if an opening brace is
-- (incorrectly) paired with a closing brace in another clause.
::Attribute clauseNumber

--

::Method init
  Expose next prev from to category subcategory source value -
    ignorable assigned assignment closing

  self~init:super
  next        = .Nil
  prev        = .Nil
  from        = ""
  to          = ""
  category    = ""
  subcategory = ""
  source      = ""
  value       = ""
  assigned    = 0
  ignorable   = 0
  closing     = .Nil

::Method isAssigned
  Expose assigned
  Return assigned
::Method setAssigned
  Expose assigned
  assigned = 1
::Method isInserted
  Return self~from == self~to

::Method "<"
  Use Strict Arg category
  If category~isA( .String ) Then Return   category~contains( self~category )
  Return self ~  "<" : super( category )

::Method "\<"
  Use Strict Arg category
  If category~isA( .String ) Then Return \ category~contains( self~category )
  Return self ~ "\<" : super( category )

::Method "<<"
  Use Strict Arg subcategory
  If subcategory~isA( .String ) Then Do
    If self~category == .EL.TAKEN_CONSTANT,  -
       subcategory~contains( self~subcategory)
      Then Return .True
      Else Return .False
  End
  Return self ~  "<<" : super( subcategory )

::Method "\<<"
  Use Strict Arg subcategory
  If subcategory~isA( .String ) Then Do
    If self~category == .EL.TAKEN_CONSTANT,  -
       subcategory~contains( self~subcategory)
      Then Return .False
      Else Return .True
  End
  Return self ~  "\<<" : super( subcategory )

--------------------------------------------------------------------------------

::Class Error.Element SubClass Element
::Attribute code
::Attribute additional
::Method init
  self~init:super
  Use Strict Arg package, code, element, additional
  If element~isA(.Element) Then
    Parse Value element~from element~to With line col endLine endCol
  Else Parse Var element line col endLine endCol
  self~from       =  line col
  self~to         =  endLine endCol
  self~category   = .EL.SYNTAX_ERROR
  self~code       =  code
  self~additional =  additional

--------------------------------------------------------------------------------

::Class Resource.Data Public SubClass Element

--------------------------------------------------------------------------------

::Class Standard.Comment Public subclass Element
::Attribute parts
::Method value -- A placeholder
  If self~category == .EL.STANDARD_COMMENT Then Return "/* A COMMENT */"
  Else Return "/* A DOC-COMMENT */"
::Method init
  Expose         package  startLine  startCol  endLine  endCol parts
  self~init:super
  Use Strict Arg package, startLine, startCol, endLine, endCol
  self~parts      = .Array~new
  self~category   = .EL.STANDARD_COMMENT
  self~ignorable  = 1 -- Classic comments are always ignorable
  self~from       = startLine startCol
  self~to         = endLine   endCol
::Method isMultiLine
  Expose startLine endLine
  Return startLine \== endLine
::Method source
  Expose         package  startLine  startCol  endLine  endCol
  Do lineNo = startLine To endLine
    line = package~source[lineNo]
    Select case lineNo
      When startLine Then Do
        If lineNo == endLine Then ret = .Array~of( line[startCol, endCol-startCol] )
        Else ret = .Array~of( SubStr( line, startCol ) )
      End
      When endLine Then ret~append( line[1, endCol-1] )
      Otherwise ret~append( line )
    End
  End
  Return ret

--------------------------------------------------------------------------------

::Class Line.Comment Public subclass Element
::Attribute parts
::Method init
  Expose package line start end
  self~init:super
  Use Strict Arg package, line, start, endLine, end
  self~parts      = .Array~new
  self~category   = .EL.LINE_COMMENT
  self~ignorable  = 1 -- Line comments are always ignorable
  self~from       = line    start
  self~to         = endLine end
::Method source
  Expose package line start endLine end
  If self~category == .EL.LINE_COMMENT Then
    Return package~source[line][start, end-start]
  Parse Value self~from With startLine  startCol
  Parse Value self~to   With endLine    endCol
  Do lineNo = startLine To endLine
    line = package~source[lineNo]
    Select case lineNo
      When startLine Then Do
        If lineNo == endLine Then
          ret = .Array~of( line[startCol, endCol-startCol] )
        Else ret = .Array~of( SubStr( line, startCol ) )
      End
      When endLine Then ret~append( line[1, endCol-1] )
      Otherwise ret~append( line )
    End
  End
  Return ret
::Method value; Return self~source

--------------------------------------------------------------------------------

::Class Operator.Character.Sequence Public subclass Element

-- "source" is the operator char as it appears in the source program, and,
-- as such, it cannot be changed.
::Attribute source Get

-- "value" is the current value of this character sequence. Initially, it
-- is the same value as "source", but it may change, for example when
-- encountering certain sequences that denote compound operators.
::Attribute value

::Method init
  Expose                        line  start  end  source  value
  self~init:super
  Use Strict Arg self~category, line, start, end, source
  value = source

::Method from
  Expose line start
  Return line start

::Method to
  Expose line end
  Return line end

--------------------------------------------------------------------------------

::Class Special.Character.Sequence Public subclass Element

::Attribute from
::Attribute source

-- "value" is the current value of this character sequence. Initially, it
-- is the same value as "source", but it may change, for example when
-- encountering certain sequences, like ": :"
::Attribute value

::Method init
  Expose                        line  start  end  source  value from
  self~init:super
  Use Strict Arg self~category, line, start, end, source
  value = source
  from = line start

::Method to
  Expose line end
  Return line end

--------------------------------------------------------------------------------

::Class Tail.Separator.Element Public subclass Element
::Constant value  "."
::Constant source "."
::Method init
  Expose                        line  col source
  self~init:super
  Use Strict Arg self~category, line, col
::Method from
  Expose line col
  Return line col
::Method to
  Expose line col
  Return line (col+1)

--------------------------------------------------------------------------------

::Class StringOrSymbol.Element Public subclass Element
::Attribute invocationType
::Attribute traceOnly                   -- For labels
::Attribute labelFor                    -- For labels
::Attribute term
::Attribute parts                       -- of a compound variable
::Attribute sourceLine Get
::Method value
  source = self~source
  If self~isAString Then Do -- Strings
    length = Length( source )
    c = Upper( Right(source,1) )
    Select Case c
      When "X" Then Return     X2C(SubStr(source,2,length-3))
      When "B" Then Return X2C(B2X(SubStr(source,2,length-3)))
      When "Y", "P", "G", "T" Then
                    Return         SubStr(source,2,length-3)~changeStr(c||c,c)
      Otherwise     Return         SubStr(source,2,length-2)~changeStr(c||c,c)
    End
  End
  Else Do -- Symbols
    Return Upper( source )
  End
::Method init
  Expose                        line  start  end  sourceLine
  self~init:super
  Use Strict Arg self~category, line, start, end, sourceLine
  self~traceOnly = 0
::Method source
  Expose sourceLine start end
  Return sourceLine[ start, end-start ]
::Method isAString
  Expose sourceLine start
  Return Pos( sourceLine[start], "'""") > 0
::Method from
  Expose line start
  Return line start
::Method to
  Expose line end
  Return line end

--------------------------------------------------------------------------------

::Class UString.Element Public SubClass StringOrSymbol.Element
::Method value
  Expose value
  Return value
::Method init
  Expose value
  Use Strict Arg category, line, start, end, sourceLine, value
  self~init:super(category, line, start, end, sourceLine)

--------------------------------------------------------------------------------

::Class WhiteSpace.Element Public subclass Element
::Method source
  Expose sourceLine start end
  Return sourceLine[ start, end-start ]
::Method value
  Expose start end sourceLine
  Return sourceLine[start, end-start]
::Method init
  Expose         line  start  end  sourceLine
  self~init:super
  Use Strict Arg line, start, end, sourceLine
  self~category = .EL.WHITESPACE
::Method from
  Expose line start
  Return line start
::Method to
  Expose line end
  Return line end

--------------------------------------------------------------------------------

::Class Shebang Public subclass Element
::Method category; Return .EL.SHEBANG
::Method init
  Expose package line start end
  self~init:super
  Use Strict Arg package, line, start, end
  self~ignorable = 1 -- Shebangs are always ignorable
::Method source
  Expose package line start end
  Return package~source[line][start, end-start]
::Method value; Return self~source
::Method from
  Expose line start
  Return line start
::Method to
  Expose line end
  Return line end

--------------------------------------------------------------------------------

::Class Inserted.Element Public subclass Element
::Method after Class
  Use Strict Arg element
  Parse Value element ~ from With line col
  new = self~new(line, col)
  next = element~next
  element~next = new
  new  ~prev = element
  If next \== .Nil Then Do
    next~prev = new
    new ~next = next
  End
  Return new
::Method init
  Expose                        line  col
  self~init:super
  Use Strict Arg self~category, line, col
  self~from = line col
  self~to   = line col

--------------------------------------------------------------------------------

::Class Inserted.Semicolon Public SubClass Inserted.Element
::Constant value ";"
::Method init
  Use Strict Arg line, col
  self~init:super(.EL.END_OF_CLAUSE, line, col)

--------------------------------------------------------------------------------

::Class Inserted.Implicit.Exit Public SubClass Inserted.Element
::Constant value ""
::Method init
  Use Strict Arg line, col
  self~init:super(.EL.IMPLICIT_EXIT, line, col)