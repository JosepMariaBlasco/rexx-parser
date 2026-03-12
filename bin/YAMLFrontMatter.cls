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
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/*                                                                            */
/* YAMLFrontMatter(source) parses the YAML front matter of a Markdown         */
/* document.                                                                  */
/*                                                                            */
/* 'source' is an array of source lines.                                      */
/*                                                                            */
/* Returns a StringTable with the parsed key-value pairs. When a key          */
/* maps to a group of subkeys, the value is itself a StringTable.             */
/* Returns .nil when no YAML front matter is found.                           */
/*                                                                            */
/* Only a subset of YAML is supported: block mappings with scalar values,     */
/* up to 3 levels of nesting. Lists, anchors, tags, flow style, and           */
/* multiline scalars are not supported.                                       */
/*                                                                            */
/******************************************************************************/

::Routine YAMLFrontMatter Public
  Use Strict Arg source

  -- The YAML front matter must start at line 1 with "---"
  If source~items == 0          Then Return .Nil
  If Strip(source[1]) \== "---" Then Return .Nil

  -- Collect YAML lines (between opening "---" and closing "---" or "...")
  Do i = 1 To source~items
    s = Strip[source[i]]
    If s \== "---", s \== "..." Then Iterate
    yamlLines = source~section(1,i)
    Signal YAMLFrontMatterFound
  End

  -- If we ran off the end without finding a closing delimiter, no valid YAML
  Return .nil

YAMLFrontMatterFound:

  Return ParseYAMLBlock(yamlLines, 1, yamlLines~items, 0)

/******************************************************************************/
/* ParseYAMLBlock -- Parse a range of YAML lines at a given indent level      */
/*                                                                            */
/* Returns a StringTable with the parsed key-value pairs.                     */
/******************************************************************************/

::Routine ParseYAMLBlock
  Use Strict Arg lines, first, last, expectedIndent

  result = .StringTable~new

  i = first
  Do i = first To last
    line     = lines[i]
    stripped = Strip(line)

    If stripped    ==  "" Then Iterate  -- Skip blank lines
    If stripped[1] == "#" Then Iterate  -- Skip comment lines

    -- Determine indentation
    stripped = Strip(line, "L")
    indent   = Length(line) - Length(stripped)

    -- If less indented than expected, we've left this block
    If indent < expectedIndent Then Leave

    -- Parse key: value
    Parse Var stripped key":"value
    key   = Strip(key)
    value = Strip(value)

    -- Remove optional quotes from value
    If Length(value) >= 2 Then Do
      If Left(value,1) == '"', Right(value,1) == '"' Then
        value = SubStr(value, 2, Length(value) - 2)
      Else If Left(value,1) == "'", Right(value,1) == "'" Then
        value = SubStr(value, 2, Length(value) - 2)
    End

    If value \== "" Then Do
      -- Simple key: value pair
      result[key] = value
      i += 1
    End
    Else Do
      -- No value: this is a group. Find the sub-block.
      subFirst = i + 1
      If subFirst > last Then Do
        i += 1
        Iterate
      End
      -- Determine the indent of the sub-block from its first non-blank line
      Do subFirst = subFirst To last
        If Strip(lines[subFirst]) \== "",  -
           Strip(lines[subFirst])[1] \== "#" Then Leave
      End
      If subFirst > last Then Do
        i += 1
        Iterate
      End
      subStripped = Strip(lines[subFirst], "L")
      subIndent = Length(lines[subFirst]) - Length(subStripped)
      -- Find the end of the sub-block: all lines with indent >= subIndent
      subLast = subFirst
      Do j = subFirst + 1 To last
        If Strip(lines[j]) == "" | Strip(lines[j])[1] == "#" Then Do
          subLast = j
          Iterate
        End
        jStripped = Strip(lines[j], "L")
        jIndent = Length(lines[j]) - Length(jStripped)
        If jIndent < subIndent Then Leave
        subLast = j
      End
      -- Recurse
      result[key] = ParseYAMLBlock(lines, subFirst, subLast, subIndent)
      i = subLast + 1
    End
  End

  Return result