Xtrtest
=======

----------------

Xtrtest is a self-consistency utility. When run
from a directory of the [Executor](../../executor) distribution,
it scans recursively the directory structure to find all
`.rex` and `.cls` programs, and then
runs [`elident`](../elident) and [`trident`](../trident)
against these files. The program stops if an error is found.

Usage
-----

<pre>
[rexx] xtrtest
</pre>

Program source
--------------

~~~rexx {source=../../../bin/xtrtest.rex}
~~~