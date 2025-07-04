/******************************************************************************/
/*                                                                            */
/* StylePatch.cls -- Highlighting style patches                               */
/* ============================================                               */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241206    0.1  First public release                                      */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250601    0.2c Add support for CSS colors                                */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/*                                                                            */
/******************************************************************************/

env = .environment
If env~StylePatch == .Nil Then env~StylePatch =  .StylePatch

--------------------------------------------------------------------------------

::Class StylePatch Public

-- Make the NEW method private

::Method new Class Private
  Use Strict Arg styles
  Return self~new:super(styles)

-- Instances should be created by calling the OF class method

::Method Of Class

  Use Strict Arg styles

  If styles~isA(.String) Then styles = .Array~of( styles )
  Else .Validate~classType( "styles",   styles,    .Array )

  clean = .Array~new
  Loop style Over styles
    style = Strip(style)
    If style[1,2] == "--" Then Iterate
    Loop line Over style~makeArray(";")
      line = Strip(line)
      If line[1,2] == "--" Then Iterate
      If line      ==   "" Then Iterate
      clean~append(line~changeStr("-"," "))
    End
  End

  patch = self~new( clean )

  Loop line Over clean
    Parse Lower Var line mode rest
    Select
      When Abbrev("all",    mode) Then Call ParseAll
      When Abbrev("element",mode) Then Call ParseElement
      When Abbrev("name",   mode) Then Call ParseName
      Otherwise Signal BadMode
    End
  End

  Return patch

ParseElement:
  Parse Var rest category highlight
  ucategory = Upper(category)
  If \ucategory~startsWith("EL."), \ucategory~startsWith("ALL.") Then
    ucategory = "EL."ucategory
  classes = .environment[ucategory]
  If classes == .Nil Then Signal BadClass
  patch~add(classes, highlight)
Return

ParseAll:
  Parse Var rest category highlight
  ucategory = Upper(category)
  If \ucategory~startsWith("ALL.") Then
    ucategory = "ALL."ucategory
  classes = .environment[ucategory]
  If classes == .Nil Then Signal BadClassSet
  patch~add(classes, highlight)
Return

ParseName:
  Parse Var rest name highlight
  uName = Upper(name)
  If \uName~endsWith(".NAME"), \uName~endsWith(".VALUE") Then
    uName = uName".NAME"
  classes = .environment[uName]
  If classes == .Nil Then Signal BadName
  patch~addName(classes, highlight)
Return

BadName:
  Raise Syntax 88.900 Additional("Invalid name '"name"'")

BadClass:
  Raise Syntax 88.900 Additional("Invalid element category '"category"'")

BadClassSet:
  Raise Syntax 88.900 Additional("Invalid element category set '"category"'")

BadMode:
  Raise Syntax 88.900 Additional("Invalid option '"line"'")

--------------------------------------------------------------------------------

::Method Init
  Expose patch. Tag2Attr. source
  Use Strict Arg source
  patch.    = .Stem~new
  Tag2Attr. = ""
  patch.!Tag2Attr = Tag2Attr.
  self~init:super

::Method getpatch
  Expose patch.
  Return patch.

::Method AddName
  Expose Tag2Attr.
  Use Strict Arg name, attributes
  constant = .EL.TAKEN_CONSTANT
  attr = self~parse( attributes )
  Tag2Attr.constant.name = attr

::Method Add
  Expose Tag2Attr.
  Use Strict Arg classes, attributes
  attr = self~parse( attributes )
  Do c Over classes~makeArray("")
    Tag2Attr.c = attr
  End

::Method parse Private
  Use Arg attributes
  option  = ''
  If attributes = "" Then Signal BadOption
  b       = "-"
  i       = "-"
  u       = "-"
  attr    = "."
  fg      = ""
  bg      = ""
  no      = 0
  Do option Over attributes~space~makeArray(" ")
    option = Lower( option )
    If option == "no" Then Do
      no = 1
      Iterate
    End
    Select Case option
      When "bold"      Then
        If no Then b = "b"
        Else       b = "B"
      When "italic"    Then
        If no Then i = "i"
        Else       i = "I"
      When "underline" Then
        If no Then u = "u"
        Else       u = "U"
      Otherwise
        If no Then Signal BadNo
        color = option
        If color~contains(":") Then Do
          Parse Var color color":"background
          If background[1] \== "#" Then Do
            bg = .HTML.Color[background]
            If bg == .Nil Then Signal BadBackground
            bg = bg || "ff"
          End
          Else Do
            bg = SubStr(background,2)
            If \"3 4 6 8"~containsWord( Length(bg) ) Then Signal BadBackground
            If \bg~dataType("X") Then Signal BadBackground
            bg = Normalize(bg)
          End
        End
        If color[1] \== "#" Then Do
          fg = .HTML.Color[color]
          If fg == .Nil Then Signal BadColor
          fg = fg || "ff"
        End
        Else Do
          fg = SubStr(color,2)
          If \"3 4 6 8"~containsWord( Length(fg) ) Then Signal BadColor
          If \fg~dataType("X") Then Signal BadColor
          fg = Normalize(fg)
        End
    End
    no = 0
  End
  If no Then Signal BadFinalNo
  Return b i u fg":"bg

Normalize:
  col = .HTML.Color[Arg(1)]
  If col \== "" Then Return col
  Select Case Length(Arg(1))
    When 6, 8 Then Return Arg(1)
    When 3 Then Do
      If Length(Arg(1)) == 6 Then Return Arg(1)
      Parse Value Arg(1) With a +1 b +1 c +1
      Return Space( a a b b c c , 0 )
    End
    When 4 Then Do
      If Length(Arg(1)) == 6 Then Return Arg(1)
      Parse Value Arg(1) With r +1 g +1 b +1 a +1
      Return Space( r r g g b b a a , 0 )
    End
  End

NormalizeAlpha:
  If Right(alpha,1) == "%" Then Do
    al = Left(alpha,Length(alpha)-1)
    If al > 100 Then Signal BadAlpha
    If al <   0 Then Signal BadAlpha
    alpha = Format(al*255/100,,0)~d2x(2)
    Return
  End
  If alpha > 1  Then Signal BadAlpha
  If alpha < 0  Then Signal BadAlpha
  alpha = Format(alpha*255,,0)~d2x(2)
  Return

BadAlpha:
  Raise Syntax 93.900 Additional("Bad alpha '"alpha"'")

BadNo:
  Raise Syntax 93.900 Additional("Invalid option 'no "option"'")

BadFinalNo:
  Raise Syntax 93.900 Additional("Invalid option 'no'")

BadOption:
  Raise Syntax 93.900 Additional("Invalid option '"option"'")

BadColor:
  Raise Syntax 93.900 Additional("Invalid color '"color"'")

BadBackground:
  Raise Syntax 93.900 Additional("Invalid background color '"background"'")
