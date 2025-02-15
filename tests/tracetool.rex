/* ---rgf, 20240721, a program that will create and/or read in the XML, JSON and
      CSV files using traceutil.cls;
      - can be used to analyze any Rexx program by creating a trace log, allowing
        to save them as xml (default), json, csv
      - allows recreating trace logs from xml, json, csv
      - allows to sort and format the trace logs by different options (see usage)
      - allows for analyzing deadlocked Rexx programs (see "-w" switch)


   2024-12-29:
      - allow running programs without altering global trace status, can be useful
        for profiling just parts of a program

   WIP: work in progress 2025-01-24

   author: Rony G. Flatscher, 2025, planned to be released under AL 2.0 and CPL 1.0

*/

signal on syntax

bShowUsage=(.sysCargs~items=0)

if \bShowUsage then
do
   mainSwitch=.sysCargs[1]~left(2)
   if mainSwitch~left(2)<>'-t' then
       bShowUsage=wordPos(mainSwitch, '-s -p -c -m')=0   -- mandatory switches
end

parse source . . fn        -- get path to this program
thisName=filespec('name',fn)

if bShowUsage then
do
   errMsg="error: no valid arguments" (arg(1)="")~?("",pp(arg(1)) "")"supplied, hence showing usage"
   .error~say(errMsg)
   say
   say .resources~usage~makeString~changeStr("\fname",thisName)
   say
   .error~say(errMsg)
   exit -1
end

if mainSwitch='-p' then    -- profile a trace log from supplied file
do
   filename=.nil
   depth=7              -- default depth for profiler tree report, 0 no limit
   if .sysCargs[2]~startsWith("-d") then
   do
      depth=.sysCargs[2]~substr(3)
      if depth<0 | datatype(depth,"W")=0 then
      do
         errMsg="Error:" "argument '-d' not immediately followed by a non-negative whole number: ["depth"]"
         .error~say(errMsg)
         exit -21
      end
   end

   filename=.sysCargs~lastItem   -- last argument is always the logfile to use
   bOK=\(fileName~isNil)   -- not .nil ?
   if bOK then
   do
      bOK=SysFileExists(fileName)   -- file exists ?
      if bOK then
      do
         lastDot=fileName~lastPos('.')
         bOK=lastDot>0
         if bOK then       -- has a proper filetype ?
         do
            ext=fileName~substr(lastDot+1)~lower
            bOK=wordPos(ext,'xml csv json')>0
         end
      end
   end

   if \bOK then      -- not o.k., communicate it
   do
      if fileName~isNil then info="is missing"
                        else info="["fileName"] does not exist or its file type is not one of 'xml', 'csv', or 'json'"
      errMsg="Error:" "'traceLogFile'" info
      .error~say(errMsg)
      exit -2
   end

   select case ext
      when 'xml' then arr=fromXmlFile(fileName)
      when 'csv' then arr=fromCsvFile(fileName)
      otherwise       arr=fromJsonFile(fileName)
   end

-- TODO: only show in debug mode?
   .error~say("profiling needs to analyze" arr~items "traceObjects ...")
   call profile arr, depth
   exit
end


else if mainSwitch="-m" then  -- manage "::options trace"
do
/*
\fname -m -{a[[r|a|i|l|n]|q|r} [-r] "filepatterns"
    - manage (add, query or remove) trace options directives (to/from the end of programs)
       -a ... add "::OPTIONS TRACE" to the end of a program
          r ... trace results (default)
          a ... trace all
          i ... trace intermediates
          l ... trace labels
          n ... trace normal

       -r ... search for files recursively

      "filepatterns" ... a quoted, space delimited string of filenames or file patterns,
                         defaults to "*.rex *.REX *.cls *.CLS *.frm *.FRM *.rxj *.rxo"
-- */
say .line":" "mainSwitch:" mainSwitch
    -- defaults
   option     ="Q"
   traceType  ="R"
   filePattern="*.rex *.cls *.frm *.rxj *.rxo"
   recursive? =.false

   do counter c1 i=2 to .sysCargs~items
      chunk=.sysCargs[i]
      select case chunk
            when "-a"      then do; option="A"; traceType ='Results'      ; end
            when "-ar"     then do; option="A"; traceType ='Results'      ; end
            when "-aa"     then do; option="A"; traceType ='All'          ; end
            when "-ai"     then do; option="A"; traceType ='Intermediates'; end
            when "-al"     then do; option="A"; traceType ='Labels'       ; end
            when "-an"     then do; option="A"; traceType ='Normal'       ; end

            when "-q"      then option="Q"   -- query
            when "-d"      then option="D"   -- delete

            when "-r"      then recursive?=.true

            otherwise
              if i=.sysCargs~items then   -- filepattern always last argument, if present
                 filePattern=chunk
              else
              do
                signal off syntax
                raise syntax 40.900 array ('unknown argument #' i':' pp(.sysCargs[i]))
              end
      end
   end
      -- carry out the operation
   if option="A" then
      call manageOptionsDirectives option, traceType, filePattern, recursive?
   else
      call manageOptionsDirectives option, filePattern, recursive?
   exit
end


else if mainSwitch="-t" then
do
   -- main switch. "-t": create trace log file, check args
   -- possible switches (all are optional) "-t[lari]", "-f[xcj]", "-a"
   traceType   ="labels"   -- default
   formatType  ="xml"      -- default
   annotate?=.false        -- default
   error?   =.false
   sleepTime= .2           -- default
   traceLogFile=.nil
   filename =.nil
   arguments =.nil
   do counter c1 i=1 to .sysCargs~items
      chunk=.sysCargs[i]
      select case chunk
            when "-tl"     then traceType='Labels'
            when "-ta"     then traceType='All'
            when "-tr"     then traceType='Results'
            when "-ti"     then traceType='Intermediate'
            when "-t"      then traceType=.nil  -- do not append "::options trace" traceType to program!

            when "-fc"     then formatType='csv'
            when "-fj"     then formatType='json'
            when "-fx"     then formatType='xml'

            when "-a"      then annotate?=.true
            when "-o"      then     -- output file
            do
               traceLogFile=.sysCargs[i+1]  -- fetch filename
               if \traceLogFile~isA(.string) then
               do
                  .error~say("switch [".sysCargs[i]"] in error, not followed by a traceLogFile name being a string ["traceLogFile"]")
                  exit -3
               end
               i+=1
            end

            otherwise
               if chunk~startsWith("-w") then   -- waiting time for threads to settle/end
               do
                  sleepTime=chunk~substr(3)
                  if \datatype(sleepTime,'N') then
                  do
                     .error~say("switch [".sysCargs[i]"] in error, time to sleep not a number")
                     exit -4
                  end
               end
               else
               do
                  if chunk[1]="-" then
                  do
                     .error~say("unknown switch [".sysCargs[i]"]")
                     exit -5
                  end

                  filename=chunk    -- assume Rexx program to trace
                  if \sysFileExists(filename) then
                  do
                     .error~say("Rexx program file ["filename"] does not exist")
                     exit -6
                  end
                     -- get arguments if any
                  arguments=.sysCargs~section(i+1) -- returns an array, possibly with 0 elements
                  leave
               end
      end
   end

   if \error?, filename~isNil then
   do
      error?=.true
      errMsg="no filename given"
   end

   if error? then
   do
      .error~say("error:" errMsg)
      exit -7
   end

   -- load program, add ::options directive at end, run it
   str=.stream~new(filename)~~open("read")
   pgm=str~arrayin
   str~close

   if traceType \== .nil then -- append global "::options trace" traceType ?
      pgm~append("::OPTIONS TRACE" traceType)

   say "--> running ["filename"], arguments=["arguments~makestring('l',', ')"]"
   say
/*--
   say "--> edited code:"
   say "-/\--"~copies(12)
   say pgm
   say "-\/--"~copies(12)
--*/

   .traceObject~option='P'    -- profile/probe
   arr=.array~new
   .traceObject~collector=arr -- collect traceObjects

      -- mark start and end of tracetool.rex in the log data
   call createInfoTraceObject thisName, filename, "traceLogStart", "(start collecting)"

   r=.routine~new(fileName, pgm)  -- create routine   -- will cause creation of a trace line

   if arguments~items=0 then
      msg=r~start("call")
   else
      msg=r~startWith("callWith",arguments)

      -- we sleep, if not yet ended, but return as early as possible
      -- hence sleeping 1/1000 sec in each loop
   dtStart    =.dateTime~new
   dtSleepTime=.TimeSpan~fromSeconds(sleepTime)
   do while msg~completed=.false, dtStart~elapsed<dtSleepTime
      call sysSleep 0.001     -- sleep 1/1000 second
   end

   call createInfoTraceObject thisName, filename, "traceLogEnd", "(end collecting)"

   .traceObject~collector=.nil   -- stop collecting traceObjects

/* --
say "."~copies(79)
do val over arr
   call dumpTraceObject val
end
say "."~copies(79)
-- */

/* --
   msg~halt       -- try to halt program
   say "--> msg~completed:" msg~completed
   say "--> msg~hasError :" msg~hasError "msg~errorCondition:" msg~errorCondition
   if msg~hasError then
   do
       call 'rgf_util2.rex'
       say thisName":" ppCondition2(msg~errorCondition)
       say "---"
   end
-- */

   if annotate? then
   do
     -- say "--> line #" .line "before annotate()"
     -- dt1=.dateTime~new
     arr=annotateRuntimeState(arr)  -- annotate traceObjects
     -- dt2=.dateTime~new
     -- say "--> line #" .line "after  annotate()" arr~items "traceObjects annotated, lasted:" dt2-dt1
   end

   -- write to logfile
   if traceLogFile~isNil then
      traceLogFile=fileName"_trace."formatType

   say
   -- say "--> line #" .line "traceLogFile=["traceLogFile"], formatType="formatType

   select case formatType
      when 'xml'  then call toXmlFile  traceLogFile, arr, "human"
      when 'csv'  then call toCsvFile  traceLogFile, arr
      when 'json' then call toJsonFile traceLogFile, arr, "human"
   end
   .error~say("--> tracelog written to:" traceLogFile)

-- say "msg~completed:" msg~completed
   if msg~completed=.false then
   do
      .error~say("--> program still running, trying to halt it ...")
      .error~say("--> msg~halt returned:" msg~halt)
      .error~say("--> after sending HALT message")
   end

   .error~say("--> msg~completed:" msg~completed "msg~hasError:" msg~hasError)

   exit
end


   --  -c -f{x|c|j} [-a] traceLogFile [newEncodedTraceLogFile]
else if mainSwitch='-c' then  -- convert existing traceLogFile to given format
do
   annotate?      =.false  -- default
   fType          =""
   traceLogFile   =.nil
   newTraceLogFile=.nil

   do counter c1 i=1 to .sysCargs~items
      chunk=.sysCargs[i]
      select case chunk
            when "-c"      then
                           do
                              if i<>1 then   -- must be first argument!
                              do
                                 .error~say("error: ('-c') must be first argument, not argument #" i)
                                 exit -20
                              end
                              iterate
                           end

            when "-fc"     then formatType='csv'
            when "-fj"     then formatType='json'
            when "-fx"     then formatType='xml'

            when "-a"      then annotate?=.true

            otherwise
               if chunk[1]="-" then
               do
                  .error~say("error: unknown switch [".sysCargs[i]"]")
                  exit -21
               end

               if traceLogFile~isNil then
               do
                  if \sysFileExists(chunk) then
                  do
                     .error~say("error: file ["chunk"] to convert does not exist")
                     exit -22
                  end
                  fTypeIn=filespec("extension",chunk)
                  if wordpos(fTypeIn, "xml json csv")=0 then
                  do
                     .error~say("error: file ["chunk"] must have a file extension of 'xml', 'json' or 'csv', found: ["fTypeIn"], aborting")
                     exit -23
                  end
                  traceLogFile=chunk      -- save file name
               end
               else if newTraceLogFile~isNil then
               do
                   newTraceLogFile=chunk
               end
               else  -- we have a superfluos argument!
               do
                  .error~say("error: unknown argument ["chunk"] in argument #" i", aborting")
                  exit -24
               end
      end
   end

   if traceLogFile~isNil | newTraceLogFile~isNil then
   do
      if traceLogFile~isNil then -- mandatory argument
      do
         .error~say("error: traceLogFile does not exist")
         exit -25
      end

      else newTraceLogFile~isNil -- optional, use traceLogFile as newTraceLogFile
      do
         newTraceLogFile=traceLogFile
      end
   end

   -- now read, process & write
      -- read
   select case ftypeIn~upper
      when 'XML' then arr=fromXmlFile(traceLogFile)
      when 'CSV' then arr=fromCsvFile(traceLogFile)
      otherwise       arr=fromJsonFile(traceLogFile)
   end
say "... line #" .line":" pp(traceLogFile)":" pp(arr~items) "traceObject items read"
      -- process
   if annotate? then -- try to annotate?
     arr=annotateRuntimeState(arr)  -- annotate traceObjects

      -- write
   -- if \newTraceLogFile~endsWith("."formatType) then   -- make sure we use correct file type
       newTraceLogFile=newTraceLogFile".converted."formatType

   -- write to logfile
   select case formatType
      when 'xml'  then call toXmlFile  newTraceLogFile, arr, "human"
      when 'csv'  then call toCsvFile  newTraceLogFile, arr
      when 'json' then call toJsonFile newTraceLogFile, arr, "human"
   end

end

else if mainSwitch='-s' then  -- show traceFileName formatted according to -o switch
do
   traceFileName=.nil
   option   ="n"  -- default to normal
   sortOrder="N"  -- default to number
   clzSortRoutine=.sortByNumber  -- default comparator
   if .sysCargs~items<2 then
   do
      .error~say( "not enough arguments, aborting...")
      exit -13
   end
   do counter c i=2 to .sysCargs~items -- assume we have both switches
      chunk=.sysCargs[i]   -- get option in uppercase

      select case chunk
         WHEN '-fn'  THEN option='n'   -- .TraceObject~option=normal
         WHEN '-ft'  THEN option='t'   -- .TraceObject~option=thread
         WHEN '-fs'  THEN option='s'   -- .TraceObject~option=standard
         WHEN '-ff'  THEN option='f'   -- .TraceObject~option=full
         WHEN '-fm'  THEN option='m'   -- use traceutil.cls floating method "formatExtensiveWithAnnotations"
         WHEN '-fm1' THEN option='m1'  -- use traceutil.cls floating method "formatExtensiveWithAnnotations"
         WHEN '-fm2' THEN option='m2'  -- use traceutil.cls floating method "formatFullWithAnnotationsDense"
         WHEN '-fm3' THEN option='m3'  -- use traceutil.cls floating method "formatFullWithAnnotationsDense2"

         WHEN '-o', '-on'  THEN clzSortRoutine=.sortByNumber
         WHEN '-oan'       THEN clzSortRoutine=.sortByAttributePool_Number
         WHEN '-oain'      THEN clzSortRoutine=.sortByAttributePool_Invocation_Number
         WHEN '-oatn'      THEN clzSortRoutine=.sortByAttributePool_Thread_Number
         WHEN '-oatin'     THEN clzSortRoutine=.sortByAttributePool_Thread_Invocation_Number
         WHEN '-oin'       THEN clzSortRoutine=.sortByInvocation_Number
         WHEN '-ortin'     THEN clzSortRoutine=.sortByInterpreter_Thread_Invocation_Number

         OTHERWISE
            if chunk[1]='-' then
            do
               .error~say( "unknown switch [".sysCargs[i]"]" )
               exit -8
            end

            argItems=.sysCargs~items
            if i<argItems then
            do
               .error~say( "expecting traceFileName as last argument (arg #" argItems "value: [".sysCargs[argItems]"]), therefore an unknown argument #" i "["chunk"] in hand, aborting" )
               exit -9
            end

            traceFileName=chunk
            if \SysFileExists(traceFileName) then  -- file exists ?
            do
               .error~say( "tracelog file ["traceFileName"] does not exist" )
               exit -10
            end

            ftype=.nil
            lpos=traceFileName~lastPos('.')
            if lpos>0 then ftype=traceFileName~substr(lpos+1)
            if wordPos(ftype~upper, "XML JSON CSV")=0 then
            do
               .error~say( "unsupported fileType ["fileType"]" )
               exit -11
            end
            leave    -- we are done
      end
   end

      -- set up formatting to use by .TraceObject
   oldOption=.traceObject~option
   if left(option,1)<>'m' then
      .traceObject~option=option
   else  -- use a method for formatting (from traceutil.cls)
   do
      if option="m3" then
         .traceObject~setMakeString(getFloatingMethod("formatFullWithAnnotationsDense2"))
      else if option="m2" then
         .traceObject~setMakeString(getFloatingMethod("formatFullWithAnnotationsDense"))
      else  -- default to "m1"
         .traceObject~setMakeString(getFloatingMethod("formatExtensiveWithAnnotations"))
   end

   select case ftype~upper
      when 'XML' then arr=fromXmlFile(traceFileName)
      when 'CSV' then arr=fromCsvFile(traceFileName)
      otherwise       arr=fromJsonFile(traceFileName)
   end

   arr~sortWith(clzSortRoutine~new)    -- sort according to switch, defaults to normal
   do traceObj over arr          -- display the traceObjects
      say traceObj~makeString
   end
   -- reset .traceObject
   if option<>'m' then .traceObject~option=oldOption
                  else .traceObject~unsetMakeString
end
else
do
   .error~say( "unknown switch ["mainSwitch"]" )
   exit -12
end

exit

syntax:
   co=condition('obj')
   call "rgf_util2.rex"
   say ppCondition2(co)
   say "---"
   raise propagate



::requires "traceutil.cls"    -- get TraceObject related utilities


/* Fill in information to inhibit runtime errors in tracetool.rex/traceutil.cls
*  and to indicate a custom TraceObject (impossible value 0 for interpreter,
*  invocation, thread; custom trace message).
*/
::routine createInfoTraceObject  -- meant for indicating start and end of tracetool in tracelog
   use strict arg thisName, fileName, toolInfo, additionalInfo

   infoTraceLine="       +++" thisName "for" pp(fileName) additionalInfo
   o=.TraceObject~new
   o~interpreter=0            -- indicate custom TraceObject
   o~invocation =0            -- indicate custom TraceObject
   o~thread     =0            -- indicate custom TraceObject
   o~traceLine=infoTraceLine
      -- pseudo StackFrame
   sf=.stringTable~new        -- indicate custom TraceObject
   sf~arguments =""
   sf~executable=.context~executable
   sf~line=0
   sf~name=toolInfo -- "n/a"
   sf~package="tracetool.rex"
   sf~target =.nil
   sf~traceLine=.nil
   sf~type   ="ROUTINE"
   o~stackframe=sf
/* --
say "-->"
call dumpTraceObject o
say "<--"
-- */
   return


   -- temporarily
::routine runner     -- in case the called program has an error, intercept it here
   use arg fn, args, option, arr
   signal on syntax
   say
   say
   say "---> "~copies(10)
   if args~isNil then
   do
      strArgs=("n/a")
      stmt='msg=r~start("call"), no args'
   end
   else
   do
      strArgs=args~toString("L",",")
      stmt='msg=r~startWith("callWith", args), args:' strArgs
   end

   say "1) creating a routine for ["fn"] ..."
   r=.routine~newFile(fn)
   say "2) about to execute as '"stmt"' | .TraceObject: option='"option"', "arr~items "traceObjects so far..."
   if args~isNil then msg=r~start("call")    -- run without arguments
                 else msg=r~startWith("callWith", args) -- supply arguments for program

      -- wait for a maximum of two seconds for getting a result, if any supplied
   count=20
   sleepTime=0.1
   say "3a) waiting" count*sleepTime "seconds for threads to end, if any ..." arr~items "traceObjects so far ..."
   do counter c while \msg~hasResult
      call sysSleep sleepTime -- sleep a bit
      if c=count then leave   -- leave after two seconds
   end
   say "3b) waited " count*sleepTime "seconds"  arr~items "traceObjects so far."

   .TraceObject~collector=.nil   -- stop collecting traceObjects
   say center("4)   option '"option"':" arr~items "traceObjects collected ",79,"-")

   if msg~completed then say "5) -> normal program completion! :)"
                    else say "5) -> program seems to hang! :("
   return msg     -- return message object

syntax:
   if VAR("SIGL") then  -- a condition occurred?
   do
      co=condition('o')
      say "SIGNAL   from calling ["fn"] with option="option "arr~items="arr~items "..."
      say "        name:" co~name":" co~instruction "sigl:" sigl
      say "   errortext:" co~errortext
      say "     message:" co~message
      say
   end
   else
      say "returned from calling ["fn"] with option='"option"' arr~items="arr~items "..."
   say "<--- "~copies(10)
   say
   say ".TraceObject~option:" .TraceObject~option ".TraceObject~collector:" .TraceObject~collector~objectname
   say
   say "waiting a little bit to have all threads exited (they generate additional traceObjects) ..."
   call syssleep .1
   .TraceObject~collector=.nil
   say center(" option '"option"': arr~items:" arr~items "",69,"-")
   return

::routine pp
  return "["arg(1)"]"

::resource usage
\fname [-t[[l|a|i|n|r]]] [-w[secs]] [-f[x|c|j]] [-o traceLogFile] [-a] filename [arguments]

    - creates and saves trace logs running filename with args

       -t ... optional trace mode: run 'filename' and save trace log, followed optionally
          a ... "trace All"
          i ... "trace Intermediate"
          l ... "trace Label" (default)
          r ... "trace Results"
          n ... do not append "::options trace xyz" statement to program

       -w ... optional wait time, defaults to .5
          secs ... 'secs' to wait to allow threads to end

       -f ... optional: format of saved trace log, followed optionally
          x ... save as xml (human legible, default)
          c ... save as csv (with headers)
          j ... save as json (human legible)

       -o traceLogFile ... optional: traceLogFile to output trace log,
                defaults to 'filename'_trace.{xml|csv|json}

       -a ... optional: annotate method clauses in trace log

       filename ... Rexx program to trace
       arg      ... blank delimited arguments to supply

       \fname will load 'filename' and append an options
       directive denoting the trace option to be used (defaults to
       '::OPTIONS TRACE LABEL'), runs the program with the supplied
       argument 'arg' and collects the traceObjects. If '-a' is supplied
       then the method clauses get annotated to display their effective
       guard state and whether they are running or blocked. This usage
       then saves the trace objects in a file named '\fname_tracelog.f'
       where 'f' will be 'xml', 'csv' or 'json' depending on flag '-f'.

or

   \fname -s [-f{N|t|s|f|m1|m2|m3}] [-o{N|an|ain|atn|atin|in|rtin}] traceLogFile
      ... shows the content of traceLogFile according to supplied -o option
      -f ... formatting option to be assigned to .TraceObject~option
         n  ... normal   default (TraceObject, option: N)
         t  ... thread   (TraceObject, option: T)
         s  ... standard (TraceObject, option: S)
         f  ... full     (TraceObject, option: F)
         m1 ... method "formatExtensiveWithAnnotations"  from traceutil.cls (show number, time)
         m2 ... method "formatFullWithAnnotationsDense"  from traceutil.cls (widths: 1 char)
         m3 ... method "formatFullWithAnnotationsDense2" from traceutil.cls (widths: 2 char)

      -o ... optional sort order for displaying the result
         n    ... sort by number (default)
         an   ... sort by attributePool, number
         ain  ... sort by attributePool, invocation, number
         atn  ... sort by attributePool, thread, number
         atin ... sort by attributePool, thread, invocation, number
         in   ... sort by invocation, number
         rtin ... sort by Rexx interpreter, thread, invocation, number

      traceLogFile ... the traceLogFile to show

or

    \fname -c -f{x|c|j} [-a] traceLogFile [newEncodedTraceLogFile]
       ... converts traceLogFile to xml, json or csv format

       -f ... format of newEncodedTraceLogFile
          x ... save as xml (human legible, default)
          c ... save as csv (with headers)
          j ... save as json (human legible)

       -a ... optional: annotate method clauses in trace log

      traceLogFile ... the traceLogFile to convert

      newTraceLogFile ... the new traceLogFile encoded according to -f,
                          if not supplied will replace 'traceLogFile'

or

\fname -p [-dn] traceLogFile

    - analyzes and displays the profile data from 'traceLogFile'

       -p  ... profile mode
       -dn ... depth, where 'n' is a whole non-negative number, 0 means unlimited,
               controls the maximal call level depth displayed in hierarchical view
               (default: n=7)

      traceLogFile ... the file containing the trace log to analyze

or

\fname -m -{a[[r|a|i|l|n]|q|d} [-r] ["filepatterns"]
    - manage (add, query or remove) trace options directives (to/from the end of programs)
       -a ... add "::OPTIONS TRACE" to the end of a program
          r ... trace results (default)
          a ... trace all
          i ... trace intermediates
          l ... trace labels
          n ... trace normal

       -q ... query whether "::OPTIONS TRACE" by tracetool.rex exists at the end of programs

       -d ... delete tracetool.rex generated "::OPTIONS TRACE" from the end of programs

       -r ... search for files recursively

      "filepatterns" ... a quoted, space delimited string of filenames or file patterns,
                         defaults to "*.rex *.cls *.frm *.rxj *.rxo"

summary:

   \fname [-t[[l|a|i|n|r]]] [-w[secs]] [-f[x|c|j]] [-o traceLogFile] [-a] filename [arguments]
   ... creates a traceLogFile from running filename
or
   \fname -s [-f{n|t|s|f|m1|m2|m3}] [-o{n|an|ain|atn|atin|in|rtin}] traceLogFile
   ... shows traceLogFile formatted according to the supplied option
or
   \fname -c -f{x|c|j} [-a] traceLogFile [newEncodedTraceLogFile]
   ... converts traceLogFile to xml, json or csv format
or
   \fname -p [-dn] traceLogFile
   ... creates and shows a profile of the invoked routines and methods

or
   \fname -m -{a[[r|a|i|l|n]|q|d} [-r] ["filepatterns"]
   ... manage (add, query or delete) trace options directives (to/from the end of programs)
::END
