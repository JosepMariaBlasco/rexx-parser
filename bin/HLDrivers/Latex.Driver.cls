/******************************************************************************/
/*                                                                            */
/* LaTeX.Highlighter.Driver.cls - LaTeX highlighter driver                    */
/* =======================================================                    */
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
/* 20250101    0.1e First version                                             */
/* 20250105    0.1f Support style patches                                     */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250502    0.2b Update --prolog not to emit HTML classes                  */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- The LaTeX.Highlighter driver class                                         --
--                                                                            --
--   This is a sample implementation.                                         --
--   - As a container, we use the listings package and the lstlisting         --
--     environment.                                                           --
--   - For italics, underline and bold, we use standard LaTeX commands.       --
--   - For foreground colors, we use the xcolor package.                      --
--   - For background colors, we use the luacolor and lua-ul packages,        --
--     and the highLight command.                                             --
--                                                                            --
-- The resulting TeX chunk has to be processed using LuaLaTeX.                --
--                                                                            --                                                                           --
-- Tested with the following style definition:                                --
--   \lstdefinestyle{rexx} {                                                  --
--     basicstyle=\fontsize{8.1pt}{10pt}\selectfont\color{white}\ttfamily     --
--   }                                                                        --
--                                                                            --
-- Warning:                                                                   --
--                                                                            --
-- Not all fonts produce acceptable results. For example, the default         --
-- monospaced font does not handle boldface. The Hack font has given us       --
-- passable results; YMMV. See https://github.com/source-foundry/Hack.        --
--                                                                            --
--------------------------------------------------------------------------------

If \.environment~hasIndex( LaTeX.Highlighter ) Then
  .environment~LaTeX.Highlighter = .LaTeX.Highlighter

::Class LaTeX.Highlighter SubClass Highlighter.Driver Public

::Method Init
  Expose Options. output
  Use Strict Arg Options., output
  self~init:super(Options., output)

::Method Prolog
  Expose Options.

  style      = Options.style

  -- We print the prolog only when requested
  If Options.prolog Then Do
    -- We need that to substitute "!" because we are using it
    -- as an escape character.
    self~say("\newcommand{\textexclamup}{!}")
  End


  envOptions   =  ""

  Parse Value self~CachedCSS(style, "rexx") With ":"background

  If background \== "" Then
    envoptions ||= ",backgroundcolor={\color[HTML]{"background"}}"

  self~say(               -
    "\begin{lstlisting}[" -
      "style=rexx,"       -
      "frame=single,"     -
      "escapechar=!,"     -
      envOptions          -
    "]")

  self~emit("!")

Exit

Color2RGB: -- hhhhhh --> r,g,b
  Parse Arg aa +2 bb +2 cc +2
  Return aa~x2d","bb~x2d","cc~x2d

::Method Highlight
  Expose Options.

  style      = Options.style

  Use Strict Arg category, subCategory, variant, tags, string

  patch = Options.!Patch
  If patch == .Nil Then patch = ""
  Else Do
    patch. = patch~getPatch
    Tag2Attr. = patch.!Tag2Attr
    Select
      When variant     \== "" Then patch = Tag2Attr.category.subCategory.variant
      When subCategory \== "" Then patch = Tag2Attr.category.subCategory
      Otherwise                    patch = Tag2Attr.category
    End
  End

  Parse Var patch patchAttrs patchColor":"patchBackground

  Parse Value self~tags2highlight(tags, "") -
    With bold italic underline color":"background

  string = LatexEscape(string)
  command = ""
  If bold              Then string = "\textbf{"string"}"
  If italic            Then string = "\textit{"string"}"
  If underline         Then string = "\underline{"string"}"

  If patchColor \== "" Then
    string = "\textcolor[HTML]{"patchColor"}{"string"}"
  Else Do
    color = ""
    Do tag Over tags~makeArray(" ")
      Parse Value Tag2Attr.tag With . . . fg":"
      If fg \== "" Then color = fg
    End
    If color \== ""    Then
      string = "\textcolor[HTML]{"color"}{"string"}"
  End

  If patchBackground \== "" Then
    string = "\highLight[{[HTML]{"patchBackground"}}]{"string"}"
  Else Do
    background = ""
    Do tag Over tags~makeArray(" ")
      Parse Value Tag2Attr.tag With . . . ":"bg
      If bg \== "" Then background
    End
    If background \== "" Then
      string = "\highLight[{[HTML]{"background"}}]{"string"}"
  End

  self~emit( string )

  Exit

Color2RGB: -- hhhhhh --> r,g,b
  Parse Arg aa +2 bb +2 cc +2
  Return aa~x2d","bb~x2d","cc~x2d

LatexEscape: -- Order is important here
  Return Arg(1) -
    ~changeStr( "\", "\textbackslash{}" ) -
    ~changeStr( "!", "\textexclamup{}"  ) -
    ~changeStr( "~", "\~{}"             ) -
    ~changeStr( "_", "\_"             ) -
    ~changeStr( " ", "~"                )

::Method startLine
  self~say("!")
  self~emit("!")

::Method Epilog
  self~say( "!" )                -- End last line
  self~say( "\end{lstlisting}" )