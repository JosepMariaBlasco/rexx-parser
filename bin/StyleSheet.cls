/******************************************************************************/
/*                                                                            */
/* StyleSheet.cls - (Very limited) stylesheet support                         */
/* ==================================================                         */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Abstract                                                                   */
/* --------                                                                   */
/*                                                                            */
/* HTML highlighting uses a set of CSS stylesheets, and we want to reuse      */
/* these stylesheets with other highlighter drivers, like ANSI or LaTeX.      */
/* To that purpose, we must be able to parse the CSS stylesheet and abstract  */
/* its contents, so that the other drivers can use it. This package contains  */
/* the necessary routines to implement this cross-driver support.             */
/*                                                                            */
/* Generally speaking, CSS parsing is a formidable task. We only support      */
/* rigidly formatted stylesheets, that are enough to produce excellent        */
/* HTML results and at the same time simple enough to be manually parser      */
/* and used by the ANSI and LaTeX drivers.                                    */
/*                                                                            */
/* Where are stylesheets located                                              */
/* -----------------------------                                              */
/*                                                                            */
/* Stylesheets reside in the /css directory. Given a style name <style>,      */
/* the corresponding stylesheet file is "/css/rexx-<style>.css".              */
/*                                                                            */
/* Format of a stylesheet file                                                */
/* ---------------------------                                                */
/*                                                                            */
/* To our parser, a stylesheet is simply a list of (possibly nested) rules.   */
/* Rules that start with ".highlight-rexx-<style>" are recognized and         */
/* processed; all other rules are ignored.                                    */
/*                                                                            */
/* ### Flattening                                                             */
/*                                                                            */
/* The parser first flattens the recognized rules in several simple ways:     */
/*                                                                            */
/*   selector1, ..., selectorn {declaration block}                            */
/*                                                                            */
/* is flattened to                                                            */
/*                                                                            */
/*   selector1 {declaration block}                                            */
/*   ...                                                                      */
/*   selectorn {declaration block}                                            */
/*                                                                            */
/* Similarly,                                                                 */
/*                                                                            */
/*   selector {declaration1; ...; declarationn}                               */
/*                                                                            */
/* is flattened to                                                            */
/*                                                                            */
/*   selector declaration1;                                                   */
/*   ...                                                                      */
/*   selector declarationn;                                                   */
/*                                                                            */
/*  ### Undoing nesting                                                       */
/*                                                                            */
/*  The flattening process eliminates nesting:                                */
/*                                                                            */
/*    .class1 {.class2 rules}                                                 */
/*                                                                            */
/*  flattens to                                                               */
/*                                                                            */
/*    .class1 .class2 rules                                                   */
/*                                                                            */
/*  while                                                                     */
/*                                                                            */
/*    .class1 {&.class2 rules}                                                */
/*                                                                            */
/*  flattens to                                                               */
/*                                                                            */
/*    .class1.class2 rules                                                    */
/*                                                                            */
/*  Other CSS combinators like +, > or ~ are not recognized.                  */
/*                                                                            */
/*  ### Format of the flattened styles                                        */
/*                                                                            */
/*  Flattening is recursive, so that, in the end, we are left up with a       */
/*  list of triples in the format                                             */
/*                                                                            */
/*    (selector, property, value)                                             */
/*                                                                            */
/*  which is excellent to implement the specificity and order algorithms.     */
/*                                                                            */
/* Limitations:                                                               */
/* ------------                                                               */
/*                                                                            */
/* + We only recognize and process rules where selectors consist              */
/*   of class names.                                                          */
/* + A selector must be composed of exactly two words. The first word must be */
/*   ".highlight-rexx-<style>", as described above. The second word must be   */
/*   an abutted list of classes starting with a period,                       */
/*   ".class1.class2...classn". Rules starting with other selectors           */
/*   are ignored.                                                             */
/* + Comment-like constructions inside strings are not supported              */
/* + Braces "{" and "}" inside strings are not supported                      */
/* + We cannot process function line constructs that use commas.              */
/* + For 'font-style', we only support 'italic' and 'normal'.                 */
/* + For 'font-weight', we only support 'bold' and 'normal'.                  */
/* + For 'text-decoration', we only support 'underline' and 'none'.           */
/* + For 'color' and 'background-color', we only support #rgb, #rgba,         */
/*   #rrggbb, #rrggbbaa, or a named color.                                    */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20250623    0.2d First version                                             */
/*                                                                            */
/******************************************************************************/

::Requires "HTMLColors.cls"

/******************************************************************************/
/* GETHIGHLIGHT                                                               */
/******************************************************************************/

--- Gets the highlighting associated to a style and a set of classes.
---
--- @param style      A Highlighter style, like 'dark' or 'light'.
--- @param myClasses  A blank-separated list of Highlighter classes,
---                   like "rx-const rx-method" (note: no initial periods).
--- @return           A string "b i u f:g", where b can be "B" (bold), "b"
---                   (no bold), or "-" (not specified), and similarly For
---                   i and u, and f and g can be the null string of a
---                   color in the format rrggbbaa.
---

::Routine GetHighlight Public

  Use Strict Arg style, myClasses

  -- Compute the stylesheet file name, if needed: If "style" is
  -- a simple style name, we look for "../css/rexx-"style".css";
  -- otherwise, we assume that "style" is in itself the file name.
  --
  -- In both cases, the file must exist.
  --

  If Pos(".", style) + Pos("/", style) > 0 Then Do
    Parse Value Reverse(style) With "ssc."elyts"-xxer"
    file = style
    style = Reverse(elyts)
  End
  Else Do
     parse source . . thisPgm
     pgmDir = filespec(location,thisPgm)
     file = pgmDir"../css/rexx-"style".css"
  End

  exists = Stream( file, "C", "Q Exists")
  If exists = "" Then Call Halt "File '"file"' does not exist."

  -- Sort the classes to get a unique key to cache the results
  myClasses = myClasses~makeArray(" ")~sort~makeString("L"," ")

  -- Prepare the cache
  pkgLocal   = .context~package~local
  key        = "CSS.STYLESHEET."style"."myclasses

  -- Check the cache
  highlight = pkgLocal[ key ]

  -- Cached? Return the cached value
  If highlight \== .Nil Then Return highlight

  -- Load and preprocess the stylesheet (it may be cached)
  style = LoadStylesheet( style, file )

  -- A (very) poor's man cascading algorithm
  --
  -- We only have to check specificity and order, and that in a single
  -- style sheet.
  --
  -- Specificity amounts to the number of classes present as selectors,
  -- as we don't process other forms of selectors.
  --
  -- Flattening will have created a different record for every property,
  -- and anyway different properties can appear in different rules.
  --
  specificity. = 0
  value.       = ""

  Do rule over style
    classes  = rule[1]
    property = rule[2]
    value    = rule[3]

    -- We first check all the classes in the rule and ensure that
    -- they are specified
    Do class Over classes~makeArray(" ")
      If WordPos(class, myClasses) == 0 Then Iterate rule
    End

    -- Mini specificity algorithm: we associate a different
    -- specificity value to each property, and update it (and the
    -- property value) only when the specificity is:
    --
    --   + Larger (more specificity), or
    --   + The same (then the order wins).
    --
    oldSpecificity = specificity.property
    If oldSpecificity <= Words(classes) Then Do
      specificity.property = Words(classes)
      value.property = value
    End
  End

  -- We now pick all the collected values, and store
  -- them in a string
  color        =  value.["color"]
  background   =  value.["background-color"]
  bold         =  value.["bold"]
  If bold      == "" Then bold = "-"
  italic       =  value.["italic"]
  If italic    == "" Then italic = "-"
  underline    =  value.["underline"]
  If underline == "" Then underline = "-"

  highlight = bold italic underline color":"background

  -- Cache these results
  pkgLocal[ key ] = highlight

  -- And return them
  Return highlight

/******************************************************************************/
/* LOADSTYLESHEET                                                             */
/******************************************************************************/

---
--- Loads and returns a flattened version of (part of) a stylesheet.
---
--- @param style      A Highlighter style, like 'dark' or 'light'.
---                   File "..\css\rexx-"style".css" is read and processed,
---                   and its contents are cached.
--- @return           A flattened array of styles, respecting the order
---                   found in the original stylesheet. Every element E
---                   contains three items: E[1] is a blank-separated list
---                   of Highlighter classes, like "rx-const rx-method"
---                   (note that we don't use initial periods). E[2] is
---                   one of "bold", "italic", "underline", "color" or
---                   "background-color". E[3] is either "B" (bold) or "b"
---                   (normal) when E[2] is "bold", and similarly for
---                   "italic" and "underline". When E[2] is "color" or
---                   "background-color", E[3] has the form "rrggbbaa".
---

::Routine LoadStylesheet

  Use Strict Arg style, file

  -- Prepare the cache
  pkgLocal = .context~package~local
  key      = "CSS.STYLESHEET."file

  -- Check the cache

  theStyle = pkgLocal[ key ]

  -- Cached? Return the cached version

  If theStyle \== .Nil Then Return theStyle

  -- Read the whole file into an array and close the file

  css = Charin( file,1,Chars(file) )~makeArray
  Call Stream file, "C", "Close"

  -- Now we will process the stylesheet. This array will hold our results
  unflattened = .Array~new

  -- We first transform the array into a string.
  -- Line ends are substituted by blanks

  css = css~makeString("Line"," ")

  -- Substitute double spaces by single spaces. This is not acceptable
  -- in a general CSS parser, but it's OK for our purposes.

  css = Space( css )

  -- Delete all comments
  --
  -- LIMITATION: We don't accept comment-like constructs inside strings.
  --
  -- Given that limitation, and since CSS comments can't be nested,
  -- it's safe to substitute them by a single blank.

  Loop While Pos("/*", css) > 0
    Parse Var css before "/*" . "*/" after
    css = before after
  End

  -- Now parse blocks delimited by braces

  open  = Pos( "{", css )
  Do While open > 0
    Call ParseBlock
    open  = Pos( "{", css )
  End

  -- Flatten everything

  newList = .Array~new
  Call Flatten "", unflattened, newList

  -- Delete cases that don't concern us

  Do i = 1 To newList~items
    classes = newList[i][1]
    Parse Value classes With check rest

    -- The first class must be ".highlight-rexx-"style

    If check \== ".highlight-rexx-"style Then Do
      newList~remove(i)
      Iterate
    End

    -- After a descendant combinator, we only accept compound
    -- selectors. Please note that the uses of the "&" nested selector
    -- will have already been flattened at this point.

    If Words(rest) \== 1 | Strip(rest)[1] \== "." Then Do
      newList~remove(i)
      Iterate
    End

    -- We now process (property, value) pairs.
    -- We only accept a very limited subset of CSS.

    Parse Value Lower(Space(newList[i][2],0)) With property":"value
    Select Case property
      When "font-style" Then Do
        property = "italic"
        Select Case value
          When "italic"    Then value = "I"
          When "normal"    Then value = "i"
          Otherwise
            newList~remove(i)
            Iterate -- We don't support oblique
        End
      End
      When "font-weight" Then Do
        property = "bold"
        Select Case value
          When "bold"      Then value = "B"
          When "normal"    Then value = "b"
          Otherwise
            newList~remove(i)
            Iterate -- We don't support other variants
        End
      End
      When "text-decoration" Then Do
        property = "underline"
        Select Case value
          When "underline" Then value = "U"
          When "none"      Then value = "u"
          Otherwise
            newList~remove(i)
            Iterate -- We don't support other variants
        End
      End
      When "color", "background-color" Then Do
        If value[1] == "#", DataType(SubStr(value,2),"X") Then Do
          f  = "f"
          ff = "ff"
          Select Case Length(value)
            When 4 Then Do
              Parse Var value +1 r +1 g +1 b
              value = Space(r r g g b b f f, 0)
            End
            When 5 Then Do
              Parse Var value +1 r +1 g +1 b +1 a
              value = Space(r r g g b b a a , 0)
            End
            When 7 Then Do
              Parse Var value +1 r +2 g +2 b
              value = Space(r g b ff, 0)
            End
            When 9 Then Do
              Parse Var value +1 r +2 g +2 b +2 a
              value = Space(r g b a, 0)
            End
            Otherwise
              newList~remove(i)
              Iterate -- Not supported
          End
        End
        Else Do -- At this point, we only support a named color
          value = .HTML.Color[value]
          If value == .Nil Then Do
            newList~remove(i)
            Iterate
          End
          value = value"ff"
        End
      End
      Otherwise Iterate
    End
    newList[i] = (Strip( ChangeStr(".", rest, " ") ), property, value)
  End

  -- Make the array dense (i.e., non-sparse) again

  newList = newList~makeArray

  -- Cache these results

  pkgLocal[ key ] = newList

  -- And return them

  Return newList

/******************************************************************************/
/* PARSEBLOCK                                                                 */
/*                                                                            */
/* We are at the beginning of a block, i.e., we just scanned a "{" character. */
/******************************************************************************/

ParseBlock: Procedure Expose css unflattened

  ------------------------------------------------------------------------------
  -- Allow constructs like
  --   {
  --     color:blue;
  --     whatever {
  --       nested stuff
  --     }
  --   }
  ------------------------------------------------------------------------------
  Parse Var css defined"{"css

  Do While Pos(";", defined) > 0
    Parse Var defined definition";"defined
    unflattened~append( Strip(definition) )
  End

  ------------------------------------------------------------------------------
  -- Pick what's inside the braces. This has to be recursive, because
  -- we can have braces inside braces.
  ------------------------------------------------------------------------------
  definition = Definition()

  ------------------------------------------------------------------------------
  --
  -- Implement a first form of flattening, by recognizing
  --    a, b, c {whatever}
  -- and expanding it to
  --   a {whatever}
  --   b {whatever}
  --   c {whatever}
  --
  -- LIMITATION: We can't parse function-like constructs that use commas
  ------------------------------------------------------------------------------

  selectors = defined
  Do While Pos(",", selectors) > 0
    Parse Var selectors selector"," selectors
    unflattened~append( (Strip(selector), definition) )
  End

  ------------------------------------------------------------------------------
  -- Store the last definition
  ------------------------------------------------------------------------------

  selector = selectors
  unflattened~append( (Strip(selector), definition) )

Return

--------------------------------------------------------------------------------
-- DEFINITION                                                                 --
--------------------------------------------------------------------------------

Definition: Procedure Expose css

  open  = Pos( "{", css )
  close = Pos( "}", css )

  If (open > 0 & close < open) | (open == 0 & close > 0) Then Do
    Parse Var css res "}" css
    Return Strip(res) -- A string
  End

  unflattened = .Array~new    -- An array
  Do While open > 0, (close == 0 | open < close )

    Call ParseBlock  -- This will add to the "unflattened" array

    open  = Pos("{", css)
    close = Pos("}", css)
  End

  If close == 0 Then Call HALT "Missing '}' in CSS."

  Parse Var css last "}" css
  If last \= "" Then unflattened~append( Strip(last) )

Return unflattened

/******************************************************************************/
/* FLATTEN                                                                    */
/******************************************************************************/

---
--- Flatten a list of rules, given a selector.
---
--- @param selector Outer selector, to be combined with the inner selectors
---                 (nesting).
--- @param rules    The list of rules to flatten.
--- @param newList  A (not necessarily empty) list to accumulate the flattened
---                 rules.
---

::Routine Flatten

  Use Arg selector, rules, newList

  --- Step over the whole list of rules
  Do rule Over rules

    --- Simple flattening: "rule" was a declaration. Just store it.

    If rule~isA(.String) Then Do
      newList~append( (selector, rule ) )
      Iterate
    End

    -- Rule is an array. Rule[1] will contain classes (with some
    -- optional operators), and Rule[2] will be a list of declarations.

    Do declarationList Over rule[2]

      -- Create a new selector
      newSelector = NewSelector(selector, rule[1])

      -- When declarationList is a string (i.e., a real declaration list),
      -- we simply append each declaration to the new list, and we are done.

      If declarationList~isA(.String) Then Do
        Call AppendAll newSelector, declarationList, newList
        Iterate
      End

      -- Now declarationList itself is an array:
      --   the first element is the (nested) selector,...

      nestedSelector = declarationList[1]
      newSelector = NewSelector(newSelector, nestedSelector)

      ---   ...and all other elements are the declarations

      Do i = 2 To declarationList~items
        declarations = declarationList[i]

        -- If declarations is an array, we should flatten it

        If declarations~isA(.Array) Then
          Call Flatten   newSelector, declarations, newList
        Else
          Call AppendAll newSelector, declarations, newList
      End

    End

  End
  Return

NewSelector: Procedure
  Use Arg selector1, selector2
  If selector2[1] == "&" Then Return Strip( selector1 || SubStr(selector2,2) )
  Return Strip( selector1 selector2 )

AppendAll: Procedure
  Use Arg selector, declarations, list
  Do declaration Over Declarations(declarations)
    list~append( (selector, declaration ) )
  End
Return

Declarations: Procedure
  Use Arg list
  declarations = .Array~new

  If Right(list,1) == ";" Then list = Left(list,Length(list)-1)

  Do While Pos(";", list) > 0
    Parse Var list declaration";"list
    declarations~append( Strip(declaration) )
  End

  declaration = list
  declarations~append( Strip(declaration) )
Return declarations

/******************************************************************************/
/* Utility routines                                                           */
/******************************************************************************/

-- Raise the HALT condition in such a way that a Syntax traceback will
-- offer some readable information.

::Routine Halt
  Interpret "Raise Halt Array('"ChangeStr("'",Arg(1),"''")"')"
