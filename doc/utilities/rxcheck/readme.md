RxCheck
=======

----------------------------

## Usage

<pre>
[rexx] rxcheck [<em>options</em>] <em>file</em>
[rexx] rxcheck [<em>options</em>] -e <em>rexx code</em>
</pre>

Perform a series of early checks on a Rexx program or
of a short code fragment, without needing to
run it first. Checks are performed syntactically, and therefore they
reach dead branches, uncalled procedures and routines, etc.

## Options

\

----------------------------------- ----------------------
`-h`, `--help`&nbsp;&nbsp;          Display this help file.
&nbsp;
Toggles:
&nbsp;
`+all`                              Activate all toggles. This is the default.
`-all`                              Deactivate all toggles.
`[+|-]iterate`                      Toggle detecting incorrect ITERATEs, or ITERATEs
                                    to inexistent targets
`[+|-]leave`                        Toggle detecting incorrect LEAVEs, or LEAVEs
                                    to inexistent targets
`[+|-]signal`                       Toggle detecting SIGNALs to inexistent labels.
`[+|-]guard`                        Toggle checking that GUARD is in a method body.
`[+|-]bifs`                         Check BIF arguments.
&nbsp;
`[+|-]debug`                        (De)activate debug mode (not affected by "all").
`[+|-]itrace`                       Toggle printing internal traceback on error
&nbsp;
Other options (all can be prefixed with "+" or "-"):
&nbsp;
`-executor`                         Enable support for Executor
`-xtr`                              Enable support for Executor
`-experimental`                     Enable experimental features
`-exp`                              Enable experimental features
`-emptyassignments`                 Allow assignments like "var =".
`-extraletters "extra"`             Allow all the characters in "extra" to function as letters.
&nbsp;
Executing short code fragments:
&nbsp;
`-e code`                           Immediately parse a string of Rexx code.
                                    This has to be the last argument.
----------------------------------- ----------------------

\

All toggles except "debug" are active by default.