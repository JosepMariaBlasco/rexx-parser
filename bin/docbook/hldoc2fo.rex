#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2020 Rexx Language Association. All rights reserved.         */
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
/* Name: HLDOC2FO.REX                                                           */
/* Type: Object REXX Script                                                   */
/*                                                                            */
-- Transform an ooRexx Docbook XML file to XSL-FO using a modified
--  Docbook stylesheet
    if arg(1) \= '' then    -- need to run docprep first
        call hldocprep arg(1)
    -- get the properties collection and verify docpath is set
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
        say 'Please run the DOCPREP command first.'
        exit
    end
    -- get the property named 'fo_files' and verify it exists
    fo_files = props~getProperty('fo_files')
    if \.file~new(fo_files)~exists then do
        say 'Unable to find' fo_files'.'
        exit
    end
    -- the *.tmp files are now created only if needed in DOCPREP
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
    -- the input xml file is now in work_folder
    indoc = work_folder||_||whichdoc'.xml'
    x_opts = '--xinclude' props~getProperty('xslt_opts')
    say time() '- Transforming' indoc 'to' fo_files||_||whichdoc'.fo'
    say 'This may take up to several minutes for the largest documents!'
    'xsltproc' x_opts '-o' fo_files||_||whichdoc'.fo pdf-hl.xsl' indoc
    say time() '- Transformation complete'

::requires doc_props.rex
