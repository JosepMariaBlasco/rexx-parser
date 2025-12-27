The compiler for experimental Rexx features
===========================================

--------------

The [compiler for experimental Rexx features, `erexx.rex`](../../../bin/erexx.rex?view=highlight),
transforms programs written in Rexx enhanced with
some of the [Parser Experimental features](../../experimental)
into a standard ooRexx program and then runs this program.

## Usage

<pre>
[rexx] erexx [<em>options</em>] <em>file</em>
</pre>

## options

---------------------------------- ----------------------
`-l`                               Print the translated program and exit immediately
`-it`, `--itrace`                  Print internal traceback on error
`-xtr`, `--executor`&nbsp;&nbsp;   Enable Executor support
---------------------------------- ----------------------
