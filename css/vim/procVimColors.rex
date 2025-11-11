/* Purpose:    create CSS files for highlight.rex (part of rexx-parser,
               https://rexx.epbcn.com/rexx-parser/) using vim (vim.org) colorschemes

   Problems:   - morning.vim ... does not use correct spelling, e.g. "StatusLine" vs. "Statusline" ! :(
                                 catering by using uppercase color names

               - there are vim cterm color names that are not W3C defined names; hence using the
                 gui RGB values instead

   Notes:      extracts/uses the 16 color terminal definitions as they use the w3c color names.
   Author:     Rony G. Flatscher
   Date:       2025-11-11
   Usage:      procVimColors.rex vimColorSchemeFile.vim
               - copy resulting .css file to the "parser\css" directory
               - then you can use, e.g.,
                  - to output to ANSI terminal
                     highlight.rex -a -n -s vim-light-zellner procVimColors.rex
                  - to output to HTML file
                     highlight.rex -h --css -n -s vim-light-zellner procVimColors.rex > procVimColors-vim-light-zellner.html
                     ... view procVimColors-vim-light-zellner.html in any browser

   Examples:   procVimColors.rex blue.vim
               - uses the definitions in "blue.vim", and creates a css file named "rexx-dark-blue.css"

               procVimColors.rex *.vim
               - creates css files for each colorscheme .vim file and creates an appropriately named
                 css file (e.g., "rexx-light-zellner.css")

   License:    Apache License 2.0 (see at bottom)
               Copyright 2025 Rony G. Flatscher

               Licensed under the Apache License, Version 2.0 (the "License");
               you may not use this file except in compliance with the License.
               You may obtain a copy of the License at

                   http://www.apache.org/licenses/LICENSE-2.0

               Unless required by applicable law or agreed to in writing, software
               distributed under the License is distributed on an "AS IS" BASIS,
               WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
               See the License for the specific language governing permissions and
               limitations under the License.
*/

plocal=.context~package~local
plocal~bDebug=.false -- .true -- .false    -- if .true, then output infos to stderr
plocal~bUseGuiDefs=.true      -- if .true uses "gui", else "cterm" for parsing

parse arg vimFileName .

if vimFileName="" then
do
   say "no vim colorscheme file given, aborting ..."
   exit -1
end

call SysFileTree vimFileName, 'vimfiles.', 'FO'
if vimfiles.0=0 then
do
   .error~say( "no input vim colorscheme file(s)" pp(vimFileName) "found, aborting ...")
   exit -2
end

templateFile="vim.css.template"
if \SysFileExists(templateFile) then
do
   .error~say( "template file" pp(templateFile) "not found, aborting ...")
   exit -3
end
s=.stream~new(templateFile)~~open("read")
templateData=s~charin(1,s~chars)~changeStr("0d0a"x,"0a"x)
s~close

   -- process all files
do i=1 to vimfiles.0
   say "processing" pp(vimfiles.i) "..."
   if filespec("name",vimfiles.i)~caselessEquals("default.vim") then
      iterate

   call createRexxCss vimfiles.i, templateData
end


::routine createRexxCss
  use arg vimFileName, templateData

  vc=.vimColors~new(vimFileName)
  if .bDebug=.true then .error~say( "vimFileName        :" pp(vimFileName))
  if .bDebug=.true then .error~say( "vc~styleName       :" pp(vc~styleName))
  if .bDebug=.true then .error~say( "vc~style           :" pp(vc~style))
  if .bDebug=.true then .error~say( "vc~colors_name     :" pp(vc~colors_name))
  if .bDebug=.true then .error~say
  if .bDebug=.true then .error~say( "vc~colorTable~items:" pp(vc~colorTable~items))
  do counter c1 idx over vc~colorTable~allindexes~sortWith(.caselessComparator~new)
     rec=vc~colorTable[idx]
     if .bDebug=.true then .error~say( c1~right(3)":" pp(idx)~left(20,'.') (idx==rec~useHighlightColor)~?("  ","->") pp(rec))
  end
  if .bDebug=.true then .error~say

  if .bDebug=.true then .error~say( "replacement table:")
  replTable=vc~replacementTable
  do counter c1 idx over replTable~allindexes~sortWith(.caselessComparator~new)
     if .bDebug=.true then .error~say( c1~right(3)":" pp(idx)~left(23,'.') pp(replTable~at(idx)))
  end

  ---
  cssFileData=createCssFileData(vc,templateData)
  if .bDebug=.true then .error~say("creating" pp(vc~cssFileName) "...")
  .stream~new(vc~cssFileName)~~open("write replace")~~charout(cssFileData)~~close
  exit

createCssFileData: procedure
  use strict arg vc, templateData

  rt=vc~replacementTable
  mb=.MutableBuffer~new(templateData)
  do idx over rt
     mb~changeStr(idx,rt[idx])
  end
  return mb~string


/* ========================================================================= */

::class vimColors

::attribute vimFileName
::attribute hlGroups          -- vim highlight group names
::attribute hlMissingGroups   -- assign missing highlight group names an alternative group name
::attribute colorNameTable    -- ucColorName -> colorName
::attribute colorTable        -- ucColorName -> colorRecord
::attribute replacementTable  -- needle -> css-formatting definitions
::attribute style             -- set background dark|light
::attribute colors_name       -- vim color name
::attribute styleName         -- name used in css-file, e.g. "vim-dark-ron" for "ron.vim"
::attribute cssFileName       -- <styleName>.css
::method init
  use local
  use strict arg vimFileName

  hlGroups="Comment","Function","Identifier","Keyword","Label","LineNr","NonText", -
           "Normal","Number", "Operator","PreProc","Special","Statement",          -
           "StatusLine","String","Tag","Type","Underlined", "WildMenu"

   -- these highlight groups are missing in quite a few vim colorscheme definitions
  hlMissingGroups=.stringTable~of( ("FUNCTION","LABEL"),  ("KEYWORD","STATEMENT"),  -
                                   ("NUMBER","CONSTANT"), ("OPERATOR","STATEMENT"), -
                                   ("STRING","CONSTANT"), ("TAG","STATEMENT"))

  colorNameTable   = .stringTable~new  -- ucColorName -> colorName
  colorTable       = .stringTable~new  -- colorName -> colorRecords
  replacementTable = .stringTable~new  -- needle -> css-formatting definitions
  self~parseVimColorFile

  styleName        = "rexx-vim-"style"-"colors_name
  cssFileName      = styleName".css"
  self~buildReplacementTable


::method parseVimColorfile
  expose vimFileName colorNameTable colorTable style colors_name hlGroups hlMissingGroups

  s=.stream~new(vimFileName)~~open("read")
  data=s~charin(1,s~chars)       -- read entire file
  s~close
  if .bDebug=.true then .error~say(vimFilename":" data~length "bytes")

  parse var data 'set background=' style ("0a"x)
  parse var data 'let g:colors_name' '=' "'"colors_name"'"

  call parse_aliases data
  call parse_color_defs data, .bUseGuiDefs~?("gui","cterm")

  call check_omitted_hl_groups

  -- now make sure that the undefined ones get values from their aliases or replacements
  -- fill-in ctermfg, ctermbg, cterm for those entries that use a different colorName definition
  do idx over colorTable
     rec=colorTable[idx]
     hc =rec~useHighlightColor
     if idx<>hc then
     do
         -- get record of "useHighlightColor" and copy ctermfg, ctermbg, cterm
         -- note: if the colorscheme .vim file has case errors in highlight names, then an error occurs here
         useRec=colorTable[hc]
         rec~FG        =useRec~FG
         rec~BG        =useRec~BG
         rec~additional=useRec~additional    -- "gui=", "cterm="
     end
  end
  return

-- parse and store the "hi! link" color assignments
parse_aliases: procedure expose colorTable colorNameTable
  use arg data
  do while data<>""
     parse var data "hi!" "link" colorname useHighlightColor ("0a"x) data
     if colorname<>"" then
     do
        colorNameTable~setEntry(colorname, colorname) -- save original spelling
        colorTable~colorname=.colorRecord~new(useHighlightColor~upper)
     end
  end
  return

-- parse the color definitions, replacing "useColor" as well
parse_color_defs: procedure expose colorTable colorNameTable
  use arg data, prefix=('cterm')

  if prefix='cterm' then
     parse var data "if s:t_Co >= 16" ("0a"x) defs "endif"
  else
  do
     parse var data "hi clear" defs -- remove line from data to parse
  end

  needleFG        =prefix"fg="
  needleBG        =prefix"bg="
  needleAdditional=prefix"="

  do counter c1 while defs<>""
     parse var defs "hi " colorName . (needleFG) fg . (needleBG) bg . (needleAdditional) additional . ("0a"x) defs

     if prefix="gui", fg[1]<>"#", bg[1]<>"#" then iterate   -- only process if at least one GUI colors, i.e. "#RRGGBB"

     if colorName<>"" then
     do
        ucColorName = colorName~upper
        if fg        ='NONE' then fg=.nil
        if bg        ='NONE' then bg=.nil
        if additional='NONE' then additional=.nil

        rec=colorTable~at(ucColorName)

        if rec~isNil then  -- no entry yet, create it
        do
           colorNameTable[ucColorName] = colorname    -- save original spelling
           colorTable[ucColorName]     =.colorRecord~new(ucColorName, fg, bg, additional)
        end
        else      -- edit record
        do
           rec~useHighlightColor=ucColorName
           rec~FG        =fg
           rec~BG        =bg
           rec~additional=additional
        end
     end
  end
  return

check_omitted_hl_groups: procedure expose colorTable colorNameTable  hlGroups hlMissingGroups
   -- make sure that we catch omitted highlighting groups and use the Normal highlighting group for them
   do hg over hlGroups
      ucHg = hg~upper
      if \colorTable~hasIndex(ucHg) then
      do
         replacement=hlMissingGroups~at(ucHg)
         if replacement=.nil then replacement="NORMAL"
         say .line": *** highlighting group" pp(hg) "missing, using '"replacement"' group instead"
         colorNameTable[ucHg]=hg
         colorTable[ucHg]    =.colorRecord~new(replacement)
      end
   end
   return


   -- this defines the replacement values
::method buildReplacementTable
  expose colorTable replacementTable hlGroups

  replacementTable["%STYLENAME%"] = self~styleName
  replacementTable["%NONE%"]      = "/* %NONE% */"    /* do not highlight */


   -- make sure that we catch omitted highlighting groups and use the Normal highlighting group for them
   do hg over hlGroups
      call highlightColor hg
   end
  return

   -- create replacement values for CSS
highlightColor: procedure expose colorTable replacementTable
  use arg colorName

  ucColorName=colorName~upper
  rec = colorTable~at(ucColorName)   -- get definitions
  if rec~isNil then  -- some colorschem .vim files do not define all highlighting groups, use group "Normal" as fall back
  do
    .error~say(.line": *** panic ***" pp(colorName) "record not found!")
    return
  end

  mb=.mutableBuffer~new
  if \rec~additional~isNil then
  do
      additional=rec~additional~changeStr(",", " ") -- if a comma separated list
      if pos('reverse'  ,additional)>0 then
      do
         if \rec~BG~isNil then    -- reverse background and foreground
            mb~append("color: ", rec~BG, " ; ")
         if \rec~FG~isNil then
            mb~append("background-color: ", rec~FG, " ;")
      end
      else
      do
         if \rec~BG~isNil then
            mb~append("background-color: ", rec~BG, " ; ")
         if \rec~FG~isNil then
            mb~append("color: ", rec~FG, " ;")
      end

      if pos('bold'     ,additional)>0 then mb~append("font-weight: bold; ")
      if pos('italic'   ,additional)>0 then mb~append("font-style: italic; ")
      if pos('underline',additional)>0 then mb~append("text-decoration: underline; ")
      if pos('undercurl',additional)>0 then mb~append("text-decoration: underline; /* instead of undercurl */ ")
  end
  else   -- no cterm, hence we need to define background and foreground colors
  do
     if \rec~BG~isNil then
        mb~append("background-color: ", rec~BG, " ; ")
     if \rec~FG~isNil then
        mb~append("color: ", rec~FG, " ;")
  end
  -- replacementTable["%"ucColorName"%"]=mb~string
  replacementTable["%"ucColorName"%"]=('/* %'ucColorName'%')~left(15) '*/' mb~string
  return


/* ========================================================================= */

::class     colorRecord
::attribute useHighlightColor
::attribute FG
::attribute BG
::attribute additional     -- NONE, bold, underline, reverse: honor bold and underline
::method init
  use local
  use strict arg useHighlightColor, FG=.nil, BG=.nil, additional=.nil

::method makestring
  use local
  return "useHighlightColor="pp(useHighlightColor)",FG="pp(isNil(FG)) || -
         ",BG="pp(isNil(BG))",additional="pp(isNil(additional))

isNil:
  if arg(1)~isNil then return 'NONE'
  return arg(1)


/* ========================================================================= */

::routine pp
  return "["arg(1)"]"

::resource copyright
   Copyright 2025 Rony G. Flatscher

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
::END

