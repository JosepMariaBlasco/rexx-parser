RxCheck
=======

----------------------------

## Usage

<pre>
[rexx] rxcheck [<em>options</em>] <em>file</em>
</pre>

Perform a series of early checks on a Rexx program, without needing to
run it first. Checks are performed syntactically, and therefore they
reach dead branches, uncalled procedures and routines, etc.

## Options

\

----------------------------------- ----------------------
`-?`, `-help`, `--help`&nbsp;&nbsp; Display this help file
`+all`                              Activate all toggles. This is the default
`-all`                              Deactivate all toggles.
`[+|-]signal`                       Toggle detecting SIGNAL to inexistent labels
`[+|-]guard`                        Toggle checking that GUARD is in a method body
`[+|-]bifs`                         Check BIF arguments
----------------------------------- ----------------------

\

All toggles are active by default