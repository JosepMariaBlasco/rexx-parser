Parse Arg version .
date = date(s)

zip     = "Rexx-Parser-"version"-"date".zip"
"del"    zip
"zip -r" zip "* -x pack.rex doc/print/* *trace.xml *.zip"