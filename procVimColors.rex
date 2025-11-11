/* Using vim colorschemes to create the CSS files.
   Currently extracts/uses the 16 color terminals as they use the w3c color names.
   rgf, 2025-11-09
*/

parse arg vimFileName .
if vimFileName="" then vimFileName="blue.vim"
if \sysFileExists(vimFileName) then
do
   .error~say( "input vim colorscheme file" pp(vimFileName) "not found, ...")
   vimFileName="..\blue.vim"
   if \sysFileExists(vimFileName) then
   do
      .error~say( "input vim colorscheme file" pp(vimFileName) "not found, aborting ...")
      exit -1
   end
end

templateFile="vim.css.template"
if \SysFileExists(templateFile) then
do
   .error~say( "template file" pp(templateFile) "not found, aborting ...")
   exit -2
end

plocal=.context~package~local
plocal~bDebug=.true      -- output infos to stderr

vc=.vimColors~new(vimFileName)
if .bDebug=.true then .error~say( "vimFileName           :" pp(vimFileName))
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
cssFileData=createCssFileData(templateFile,vc)
say cssFileData
if .bDebug=.true then .error~say("creating" pp(vc~cssFileName) "...")
.stream~new(vc~cssFileName)~~open("write replace")~~charout(cssFileData)~~close

exit

createCssFileData: procedure
  use strict arg templateFile, vc

  s=.stream~new(templateFile)~~open("read")
  templateData=s~charin(1,s~chars)~changeStr("0d0a"x,"0a"x)
  s~close
  rt=vc~replacementTable
  mb=.MutableBuffer~new(templateData)
  do idx over rt
     mb~changeStr(idx,rt[idx])
  end
  return mb~string


/* ========================================================================= */

::class vimColors

::attribute vimFileName
::attribute colorTable
::attribute replacementTable
::attribute style       -- set background dark|light
::attribute cssFileName
::attribute colors_name -- vim color name
::attribute styleName    -- name used in css-file, e.g. "vim-dark-ron" for "ron.vim"
::method init
  use local
  use strict arg vimFileName

  colorTable       = .stringTable~new  -- contains colorRecords
  replacementTable = .stringTable~new
  self~parseVimColorFile

  styleName        = "rexx-vim-"style"-"colors_name
  cssFileName      = styleName".css"
  self~buildReplacementTable


::method parseVimColorfile
  expose vimFileName colorTable style colors_name

  s=.stream~new(vimFileName)~~open("read")
  data=s~charin(1,s~chars)       -- read entire file
  s~close
  if .bDebug=.true then .error~say(vimFilename":" data~length "bytes")

  parse var data 'set background=' style ("0a"x)
  parse var data 'let g:colors_name' '=' "'"colors_name"'"
  call parse_aliases data
  call parse_color_defs data

  -- fill-in ctermfg, ctermbg, cterm for those entries that use a different colorName definition
  do idx over colorTable
     rec=colorTable~at(idx)
     if idx<>rec~useHighlightColor then
     do
         -- get record of "useHighlightColor" and copy ctermfg, ctermbg, cterm
         useRec=colorTable~at(rec~useHighlightColor)
         rec~ctermFG=useRec~ctermFG
         rec~ctermBG=useRec~ctermBG
         rec~cterm  =useRec~cterm
     end
  end
  return

-- parse and store the "hi! link" color assignments
parse_aliases: procedure expose colorTable
  use arg data
  do counter c1 while data<>""
     parse var data "hi!" "link" colorname useHighlightColor ("0a"x) data
     if colorname<>"" then
        colorTable[colorname]=.colorRecord~new(useHighlightColor)
  end
  return

-- parse the color definitions, replacing "useColor" as well
parse_color_defs: procedure expose colorTable
  use arg data
  parse var data "if s:t_Co >= 16" ("0a"x) defs "endif"
  do counter c1 while defs<>""
     parse var defs "hi " colorName . "ctermfg="ctermfg . "ctermbg="ctermbg . "cterm="cterm . ("0a"x) defs
     if colorName<>"" then
     do
        if ctermfg='NONE' then ctermfg=.nil
        if ctermbg='NONE' then ctermbg=.nil
        if cterm  ='NONE' then cterm  =.nil

        rec=colorTable~at(colorName)
        if rec~isNil then  -- no entry yet, create it
           colorTable[colorName]=.colorRecord~new(colorname, ctermfg, ctermbg, cterm)
        else      -- edit record
        do
           rec~useHighlightColor=colorName
           rec~ctermFG=ctermfg
           rec~ctermBG=ctermbg
           rec~cterm  =cterm
        end
     end
  end
  return



   -- this defines the replacement values
::method buildReplacementTable
  expose colorTable replacementTable

  replacementTable["%STYLENAME%"] = self~styleName
  replacementTable["%NONE%"]      = "/* %NONE% */"    /* do not highlight */

  call highlightColor "Comment"
  call highlightColor "Define"   -- variables etc.
  call highlightColor "Function"
  call highlightColor "Identifier"
  call highlightColor "Keyword"
  call highlightColor "LineNr"
  call highlightColor "NonText"
  call highlightColor "Normal"
  call highlightColor "Number"
  call highlightColor "Operator"
  call highlightColor "Special"
  call highlightColor "Statement"
  call highlightColor "StatusLine"
  call highlightColor "String"
  call highlightColor "Tag"
  call highlightColor "Type"
  call highlightColor "Underlined"
  call highlightColor "WildMenu"
  return

   -- create replacement values for CSS
highlightColor: procedure expose colorTable replacementTable
  use arg colorName

  uColorName=colorName~upper
  rec = colorTable~at(colorName)   -- get Normal definitions

  mb=.mutableBuffer~new
  if \rec~cterm~isNil then
  do
      cterm=rec~cterm~changeStr(",", " ") -- if a comma separated list
      if pos('reverse'  ,cterm)>0 then
      do
         if \rec~ctermBG~isNil then    -- reverse background and foreground
            mb~append("color: ", rec~ctermBG, " ; ")
         if \rec~ctermFG~isNil then
            mb~append("background-color: ", rec~ctermFG, " ;")
      end
      else
      do
         if \rec~ctermBG~isNil then
            mb~append("background-color: ", rec~ctermBG, " ; ")
         if \rec~ctermFG~isNil then
            mb~append("color: ", rec~ctermFG, " ;")
      end

      if pos('bold'     ,cterm)>0 then mb~append("font-weight: bold; ")
      if pos('italic'   ,cterm)>0 then mb~append("font-style: italic; ")
      if pos('underline',cterm)>0 then mb~append("text-decoration: underline; ")
  end
  else   -- no cterm, hence we need to define background and foreground colors
  do
     if \rec~ctermBG~isNil then
        mb~append("background-color: ", rec~ctermBG, " ; ")
     if \rec~ctermFG~isNil then
        mb~append("color: ", rec~ctermFG, " ;")
  end
  -- replacementTable["%"uColorName"%"]=mb~string
  replacementTable["%"uColorName"%"]=('/* %'uColorName'%')~left(15) '*/' mb~string
  return


/* ========================================================================= */

::class     colorRecord
::attribute useHighlightColor
::attribute ctermFG
::attribute ctermBG
::attribute cterm       -- NONE, bold, underline, reverse: honor bold and underline
::method init
  use local
  use strict arg useHighlightColor, ctermFG=.nil, ctermBG=.nil, cterm=.nil

::method makestring
  use local
  return "useHighlightColor="pp(useHighlightColor)",ctermFG="pp(isNil(ctermFG)) || -
         ",ctermBG="pp(isNil(ctermBG))",cterm="pp(isNil(cterm))

isNil:
  if arg(1)~isNil then return 'NONE'
  return arg(1)


/* ========================================================================= */

::routine pp
  return "["arg(1)"]"

