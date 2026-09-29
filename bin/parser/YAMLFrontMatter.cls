/******************************************************************************/
/*                                                                            */
/* YAMLFrontMatter.cls -- Parse YAML front matter from a Markdown source      */
/* ====================================================================       */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
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
/* 20260311    0.5   First public release                                     */
/* 20260925    0.5a  Comments at the end of a line ("total: 45  # minutes")   */
/* 20260926    0.6   Full YAML 1.2: the parsing is done by yaml.cls, which    */
/*                   comes with ooRexx (5.2.0 and later). This file is now    */
/*                   an adapter: it gives RexxPub the tree it expects.        */
/* 20260927          A UTF-8 BOM before the opening "---" is removed          */
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/*                                                                            */
/* YAMLFrontMatter(source) parses the YAML front matter of a Markdown         */
/* document.                                                                  */
/*                                                                            */
/* 'source' is an array of source lines. The front matter starts at line 1    */
/* with "---" and ends at the next "---" or "...". Returns .nil when there    */
/* is no front matter (no "---" at line 1, or no closing line).               */
/*                                                                            */
/* The YAML itself is read by yaml.cls, the YAML 1.2 class that comes with    */
/* ooRexx: block and flow mappings and sequences, quoted and block scalars,   */
/* escapes, anchors and aliases, comments. What comes back is normalized to   */
/* the tree the RexxPub pipelines expect:                                     */
/*                                                                            */
/*   mapping   a StringTable (also the front matter as a whole; one that is   */
/*             not a mapping, or is empty, gives an empty StringTable)        */
/*   sequence  an Array, its items normalized in the same way                 */
/*   boolean   the string "true" or "false" (YAML 1.2 core schema, plus the   */
/*             YAML 1.1 words yaml.cls also takes: yes/no, on/off)            */
/*   null      a key whose value is null ("key:", "key: ~", "key: null") is   */
/*             left out, as if it had not been written: "not specified".      */
/*             In a sequence a null item is ""                                */
/*   others    the string yaml.cls gives (numbers are canonical: 012 is 12)   */
/*                                                                            */
/* Invalid YAML raises SYNTAX 98.900; its additional information is           */
/* "line N: invalid YAML front matter: <what>", with N a line of 'source'     */
/* (or no "line N: " when the line is not known). Pandoc would reject the     */
/* same front matter; this says so first, and more clearly.                   */
/* CheckedYAMLFrontMatter(source, file) is the same, but on invalid YAML it   */
/* reports "file:N: ..." on .Error and returns "", so that the caller stops   */
/* the way it stops for its other errors: the command-line tools use it.      */
/*                                                                            */
/******************************************************************************/

::Requires "yaml.cls"

::Routine YAMLFrontMatter Public
  Use Strict Arg source

  If source~items == 0          Then Return .Nil

  -- A UTF-8 byte order mark (EF BB BF), which Windows editors like to put at
  -- the start of a file, is not part of the text. Left in, line 1 reads as
  -- BOM || "---", not "---", and the front matter was silently not read at
  -- all (Rony, 27-sep: skin fields, footer, everything). It is removed from
  -- 'source' itself, so that the caller goes on with the text without it.
  If source[1]~startsWith("EFBBBF"x) Then source[1] = source[1]~substr(4)

  -- The YAML front matter must start at line 1 with "---"
  If Strip(source[1]) \== "---" Then Return .Nil

  -- Collect YAML lines (between opening "---" and closing "---" or "...")
  Loop i = 2 To source~items
    s = Strip(source[i])
    If s \== "---", s \== "..." Then Iterate
    yamlLines = source~section(2,i-2)
    Signal YAMLFrontMatterFound
  End

  -- If we ran off the end without finding a closing delimiter, no valid YAML
  Return .nil

YAMLFrontMatterFound:

  If yamlLines~items == 0 Then Return .StringTable~new

  Signal On Syntax Name InvalidYAML
  tree = .Yaml~new~parseArray(yamlLines)
  Signal Off Syntax

  If \tree~isA(.Table) Then Return .StringTable~new
  Return Normalized(tree)

InvalidYAML:
  co = Condition("O")
  additional = co["ADDITIONAL"]
  what = ""
  If additional~isA(.Array), additional~items > 0 Then what = additional[1]
  If \what~isA(.String) Then Raise Propagate
  If \what~startsWith("YamlError: ") Then Raise Propagate

  -- "YamlError: <message> (line N)", and maybe a line with the context
  Parse Var what "YamlError: " what "0a"x
  line = ""
  If what~endsWith(")") Then Do
    at = what~lastPos(" (line ")
    If at > 0 Then Do
      n = what~substr(at + 7)~strip("T", ")")
      If n~dataType("W") Then Do
        what = Left(what, at - 1)
        -- n counts the lines of the front matter from 1; 'source' has the
        -- opening "---" before them. But yaml.cls up to ooRexx 5.3.0 gives
        -- one more than the line in error (fixed in later versions): ask
        -- the yaml.cls at hand how it counts.
        line = n + 1 - YamlLineBias()
      End
    End
  End
  -- A tab in the indentation comes without a line: find it.
  If line == "", what~startsWith("Tab character in indentation") Then
    Loop j = 1 To yamlLines~items
      lead = yamlLines[j]~verify(" "||"09"x)
      If lead == 0 Then lead = Length(yamlLines[j]) + 1
      If Pos("09"x, Left(yamlLines[j], lead - 1)) == 0 Then Iterate
      line = j + 1
      Leave
    End

  message = "invalid YAML front matter:" what
  If line \== "" Then message = "line" line":" message
  Raise Syntax 98.900 Additional(message)

/******************************************************************************/
/* YamlLineBias -- 1 if yaml.cls reports errors one line too far, else 0      */
/*                                                                            */
/* The yaml.cls of ooRexx 5.2.0 and 5.3.0 reports, for most errors, the line  */
/* AFTER the one in error; later versions report the right one. An error on   */
/* line 1 tells which: it comes back as line 2 or as line 1.                  */
/******************************************************************************/

::Routine YamlLineBias
  Signal On Syntax Name Probed
  probe = .Yaml~new~parseArray(.Array~of("a: b: c"))
  Return 0                                    -- no error at all: no bias known
Probed:
  text = Condition("O")["ADDITIONAL"]
  If text~isA(.Array) Then text = text[1]
  If \text~isA(.String) Then Return 0
  If text~pos("(line 2)") > 0 Then Return 1
  Return 0

/******************************************************************************/
/* CheckedYAMLFrontMatter -- YAMLFrontMatter, for a command-line tool         */
/*                                                                            */
/* Invalid YAML is reported on .Error ("file:N: invalid YAML front matter:    */
/* ...") and gives "", which YAMLFrontMatter never returns: the caller then   */
/* stops. (An EXIT here would only end this routine, not the program.)        */
/******************************************************************************/

::Routine CheckedYAMLFrontMatter Public
  Use Strict Arg source, file

  Signal On Syntax Name Invalid
  Return YAMLFrontMatter(source)

Invalid:
  co = Condition("O")
  If co["CODE"] \== "98.900" Then Raise Propagate
  message = co["ADDITIONAL"][1]
  If \message~isA(.String) Then Raise Propagate
  If Pos("invalid YAML front matter:", message) == 0 Then Raise Propagate
  If message~startsWith("line ") Then Do
    Parse Var message "line " n ": " message
    .Error~Say(file":"n":" message)
  End
  Else .Error~Say(file":" message)
  Return ""

/******************************************************************************/
/* Normalized -- the tree yaml.cls gives, as RexxPub expects it               */
/******************************************************************************/

::Routine Normalized
  Use Strict Arg node

  Select
    When node~isA(.YamlBoolean) Then
      If node~value Then Return "true"
      Else               Return "false"
    When node~isA(.Table) Then Do
      map = .StringTable~new
      Do key Over node~allIndexes
        value = node[key]
        If value == .Nil Then Iterate              -- "key:" is "not given"
        name = key~request("String")
        If name == .Nil Then Iterate               -- a complex key
        map[name] = Normalized(value)
      End
      Return map
    End
    When node~isA(.Array) Then Do
      list = .Array~new
      -- Not "Do item Over": it skips the slots that hold .nil (a null item).
      Do i = 1 To node~items
        item = node[i]
        If item == .Nil Then list~append("")
        Else                 list~append(Normalized(item))
      End
      Return list
    End
    Otherwise Return node
  End
