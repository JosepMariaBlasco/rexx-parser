#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2020-2026, Rexx Language Association. All rights reserved.   */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* http://www.oorexx.org/license.html                                         */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/
/* Name: HLDOC2HTML.REX                                                       */
/* Type: Object REXX Script                                                   */
/*                                                                            */
/* Highlighted HTML build.  Drop-in companion for DOC2HTML that transforms    */
/* the prepared DocBook sources into chunked HTML with Rexx syntax            */
/* highlighting, using html-hl.xsl instead of html.xsl, and that ships the    */
/* highlighting stylesheets and the style chooser alongside the pages.        */
/*                                                                            */
/* Usage:                                                                     */
/*   [rexx] hldocprep [options] <bookname>                                    */
/*   [rexx] hldoc2HTML                                                        */
/*                                                                            */
/* or, in one step:                                                           */
/*   [rexx] hldoc2HTML <bookname>                                             */
/*                                                                            */
/* Unlike the PDF branch, nothing here is generated per token or per style:   */
/* the stock DocBook XSL already turns the <phrase role="rx-..."> elements    */
/* emitted by hldocprep into <span class="rx-..."/>, and the colours are a    */
/* matter of CSS.  That is also why the reader can switch style in the        */
/* browser: the token markup is identical for every style, so switching is    */
/* a matter of relabelling the wrapper and activating another sheet.          */
/*                                                                            */
/*----------------------------------------------------------------------------*/
    -- If setup.rex unpacked the Parser into .\rexx-parser, make its bin/
    -- directory discoverable for this process before anything looks for it.
    call AddLocalParser
    if arg(1) \= '' then    -- need to run hldocprep first
        call hldocprep arg(1)
    -- get the properties file and verify docpath is set
    props = .doc.props
    docpath = props~getProperty('docpath', '')
    if docpath = '' then do
        say 'You must specify the path to the ooRexx docs.'
        say 'Please run the DOCPATH command first.'
        exit
    end
    -- verify whichdoc is set
    whichdoc = props~getProperty('whichdoc', '')
    if whichdoc = '' then do
        say 'You must specify the name of the ooRexx document to be built.'
        say 'Please run the HLDOCPREP command first.'
        exit
    end
    -- verify that hldocprep has generated the highlighting stylesheet
    if \.file~new('html-hl.xsl')~exists then do
        say 'Unable to find html-hl.xsl.'
        say 'Please run the HLDOCPREP command first.'
        exit
    end
    -- get current date and time (needed later for HTML files check)
    start_time = .dateTime~new
    whichOS = props~getProperty('OS_type')~left(1)~upper
    env = 'ENVIRONMENT'
    select
        when whichOS = 'W' then do  -- Windows needs this, has no default value
            dtd_cat = '.\DocBook_Files\catalog.xml'
            xsl_cat = '.\DocBook_Files\docbook-xsl-nons-1.79.2\catalog.xml'
            call value 'xml_catalog_files', dtd_cat xsl_cat, env
        end
        when whichOS = 'D' then do  -- Mac (Darwin)
            xml_cat = props~getProperty('XMLcatalog')
            if xml_cat <> '' then
                call value 'XML_CATALOG_FILES', xml_cat, env
        end
        otherwise                   -- Linux has a default value
            nop
    end
    _ = props~getProperty('dir_sep')    -- either \ or /
    work_folder = props~getProperty('work_folder')
    indoc = work_folder||_||whichdoc'.xml'
    -- get the property named 'HTML_folders' and verify it exists
    HTML_folders = props~getProperty('HTML_folders')
    if \.file~new(HTML_folders)~exists then do
        say 'Unable to find' HTML_folders'.'
        exit
    end
    base_dir = HTML_folders||_||whichdoc||_ -- the folder for this document
    theDir = .file~new(base_dir)
    if \theDir~exists then
        theDir~makeDir
    x_opt1 = '--stringparam base.dir' base_dir
    x_opt2 = '--stringparam package ooRexx_Documentation-Open_Object_Rexx-5.0-en-US-0-0'
    x_opt3 = '--stringparam prod.url https://www.oorexx.org/'
    x_opt4 = '--stringparam xsltproc.version 1.1.26'
    x_opts = '--xinclude' x_opt1 x_opt2 x_opt3 x_opt4 props~getProperty('xslt_opts')
    say time() 'Transforming' indoc 'into' base_dir '(with highlighting)'
    say 'This may take up to several minutes for the largest documents!'
    'xsltproc' x_opts 'html-hl.xsl' indoc
    xcpyf = resolve_book(docpath, 'ooRexx')||_'en-US'_  -- common source folder
    xcpyt = base_dir'Common_Content'_
    say 'Updating the files from the CSS folder if required.'
    call do_rxcopy xcpyf'css', xcpyt'css'
    say 'Updating the files from the common images folder if required.'
    call do_rxcopy xcpyf'images', xcpyt'images'
    inpath = docpath||_||whichdoc||_'en-US'_    -- actual source folder
    if .file~new(inpath'images')~exists then do
        say 'Updating the files from the' whichdoc 'images folder if required.'
        call do_rxcopy inpath'images', base_dir'images'
    end
    -- ship the highlighting stylesheets and the style chooser
    call copy_highlighting xcpyt
    -- check that the (new) HTML files have been created
    theFiles = .file~new(base_dir)~listFiles
    fileCount = 0
    do aFile over theFiles
        if aFile~isDirectory then
            iterate
        created_time = aFile~lastmodified   -- a DateTime object
        if start_time~compareTo(created_time) = -1 then -- aFile is new
            fileCount += 1
        else                                -- must be a left over file
            aFile~delete
    end
    if fileCount = 0 then
        fileCount = 'No'
    else do
        if props~getLogical('zip_HTML') then
            call HTML2zip base_dir, whichdoc
    end
    say time() fileCount 'HTML files were created'

/*----------------------------------------------------------------------------*/
/* ADDLOCALPARSER                                                             */
/*                                                                            */
/* If setup.rex has unpacked the Rexx Parser into .\rexx-parser (relative to  */
/* the tools/bldoc_orx/ directory), prepend its bin\ directory to this        */
/* process's REXX_PATH so that findProgram and loadPackage resolve the local  */
/* copy without a system-wide install.  ooRexx consults REXX_PATH at each     */
/* program lookup, so the process-local change is enough; it is not meant to  */
/* persist between runs.                                                      */
/*                                                                            */
/* Does nothing when the local copy is absent, so a system-wide install still */
/* works as before, and is idempotent, so calling it here and again inside a  */
/* nested hldocprep run does not stack duplicate path entries.                */
/*----------------------------------------------------------------------------*/

::routine AddLocalParser
    sep = .file~separator                        -- "\" on Windows
    pathSep = .file~pathSeparator                -- ";" on Windows

    binDir = .file~new('rexx-parser' || sep || 'bin')

    -- Nothing unpacked locally: leave the search path untouched.
    if \.file~new(binDir~absolutePath || sep || 'Rexx.Parser.cls')~exists then
        return .false

    absBin = binDir~absolutePath
    rexxPath = value('REXX_PATH', , 'ENVIRONMENT')

    if rexxPath == '' then
        call value 'REXX_PATH', absBin, 'ENVIRONMENT'
    else if \CaselessPathHas(rexxPath, absBin, pathSep) then
        call value 'REXX_PATH', absBin || pathSep || rexxPath, 'ENVIRONMENT'

    return .true

/*----------------------------------------------------------------------------*/
/* CASELESSPATHHAS                                                            */
/*                                                                            */
/* True when dir is already one of the path-separator-delimited entries in    */
/* pathString, compared without regard to case.                               */
/*----------------------------------------------------------------------------*/

::routine CaselessPathHas
    use strict arg pathString, dir, pathSep

    loop entry over pathString~makeArray(pathSep)
        if entry~strip~caselessEquals(dir) then return .true
    end

    return .false

::requires "doc_props.rex"

/*----------------------------------------------------------------------------*/
/* COPY_HIGHLIGHTING                                                          */
/*                                                                            */
/* Copy the Rexx highlighting stylesheets and the client-side style chooser   */
/* into the book's Common_Content, next to the sheets doc2HTML already puts   */
/* there.  The sources are found relative to Rexx.Parser.cls, wherever the    */
/* Parser is installed, so nothing here depends on the current directory.     */
/*                                                                            */
/* The pages link every sheet, but all except the default carry               */
/* media="not all", so a reader's browser only fetches the one it is asked    */
/* to show.                                                                   */
/*----------------------------------------------------------------------------*/

::routine copy_highlighting
    use strict arg common_dir

    sep = .file~separator

    loc = .context~package~findProgram('Rexx.Parser.cls')
    if loc == .nil then do
        say 'Warning: the Rexx Parser was not found; highlighting'
        say '  stylesheets have not been copied. The pages will be unstyled.'
        return
    end

    binDir     = filespec('Location', loc)
    parserRoot = .file~new(binDir || '..')~absolutePath
    cssSrc     = parserRoot || sep || 'css'
    jsSrc      = parserRoot || sep || 'js' || sep || 'style-chooser.js'

    -- the highlighting sheets
    if .file~new(cssSrc)~exists then do
        say 'Updating the Rexx highlighting stylesheets if required.'
        call SysFileTree cssSrc || sep || 'rexx-*.css', 'sheets.', 'FO'
        destDir = .file~new(common_dir'css')
        if \destDir~exists then
            destDir~makeDirs
        lst = .array~new
        do i = 1 to sheets.0
            base = .file~new(sheets.i)~name
            if base~caselessStartsWith('rexx-test') then iterate  -- dev-only
            call rxcopy .file~new(sheets.i), destDir, lst
        end
        ctr = lst~items
        ? = (ctr = 1)~?('', 's')
        say ctr 'stylesheet'? 'copied.'
    end
    else
        say 'Warning: no css/ directory found at' cssSrc'.'

    -- the client-side style chooser
    if .file~new(jsSrc)~exists then do
        say 'Updating the style chooser script if required.'
        destDir = .file~new(common_dir'js')
        if \destDir~exists then
            destDir~makeDirs
        lst = .array~new
        call rxcopy .file~new(jsSrc), destDir, lst
        ctr = lst~items
        ? = (ctr = 1)~?('', 's')
        say ctr 'script'? 'copied.'
    end
    else
        say 'Warning: style-chooser.js not found at' jsSrc'.'

    return

/*----------------------------------------------------------------------------*/
/* RESOLVE_BOOK                                                               */
/*                                                                            */
/* Return the real path of a book directory under docpath, tolerating a       */
/* difference in capitalisation.                                              */
/*                                                                            */
/* The common content is asked for as 'ooRexx' but checked out as 'oorexx'.   */
/* On Windows and macOS the file system is case insensitive and nobody        */
/* notices; on Linux the lookup fails, and it fails silently -- the copy      */
/* step just reports that no files were copied and the book ends up with no   */
/* stylesheet at all.  Resolving the name here keeps one script working on    */
/* all three platforms.                                                       */
/*----------------------------------------------------------------------------*/

::routine resolve_book
    use strict arg docpath, wanted

    sep  = .file~separator
    cand = docpath || sep || wanted
    if .file~new(cand)~exists then
        return cand

    theDir = .file~new(docpath)
    if theDir~exists then do
        do anObj over theDir~listFiles
            if anObj~isDirectory, upper(anObj~name) == upper(wanted) then
                return anObj~absolutePath
        end
    end

    return cand     -- not found; let the caller report it as before

/*----------------------------------------------------------------------------*/
/* DO_RXCOPY and RXCOPY - copied verbatim from doc2HTML.rex                   */
/*----------------------------------------------------------------------------*/

::routine do_rxcopy
    parse arg from_dir, to_dir
    lst = .array~new
    call rxcopy .file~new(from_dir), .file~new(to_dir), lst
    ctr = lst~items
    ? = (ctr = 1)~?('', 's')
    say ctr 'file'? 'copied.'

::routine rxcopy
    use arg srceObj, destObj, fn_list=(.array~new)
    -- expects srce and dest to be file objects AND dest to be a directory
    --  if srce is a single file, dest must already exist
    --  fn_list is an optional array (or other ordered collection) that will
    --  receive the names of the files that were copied
    dir_sep = .RexxInfo~directorySeparator
    select
        when srceObj~isFile then do -- copying a single file
            -- do we need to copy it?
            srceDate = srceObj~lastModified
            destFile = destObj~absolutePath || dir_sep || srceObj~name
            destDate = .file~new(destFile)~lastModified
            -- above may be .nil if destFile doesn't exist
            select
                when destDate == .nil then
                    cpy? = .true
                when srceDate > destDate then
                    cpy? = .true
                otherwise
                    cpy? = .false
            end
            if cpy? then do
                inFile = .stream~new(srceObj)
                inData = inFile~charIn(, inFile~chars)
                inFile~close
                outFile = .stream~new(destFile)~~open(write replace)
                outFile~~charOut(inData)~close
                fn_list~append(infile~qualify)
            end
        end
        when srceObj~isDirectory then do    -- copying a directory
            if \destObj~exists then
                destObj~makeDirs
            srceList = srceObj~listFiles    -- array of file objects
            do anObj over srceList
                if anObj~isDirectory then do
                    destName = destObj~absolutePath
                    theDest = .file~new(destName || dir_sep || anObj~name)
                end
                else
                    theDest = destObj
                call rxcopy anObj, theDest, fn_list
            end
        end
        otherwise   -- neither file nor directory; probably typo
            say 'Unknown source object:' srceObj~absolutePath'; check spelling'
    end
    return
