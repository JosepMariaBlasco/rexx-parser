RexxPub: A Rexx Publisher Framework
===================================

--------------------------

Provided document classes
-------------------------

+ [Article](article/).

Dependencies
------------

+ Pandoc, to transform Markdown into HTML5.
+ [Pagedjs-cli](#Pagedjs-cli), to transform HTML5 to PDF.
+ [Node.js](#Node.js), needed by paged-cli.
  Node.js includes npm.

Installing Node.js and npm under Windows {#Node.js}
----------------------------------------

Download Node.js from <https://nodejs.org> and install it.
Make sure that the option to add Node.js to the
PATH is enabled.

You can test that `node` and `npm` are installed correctly
by running

```
node --version
```

and

```
npm --version
```

from the command line (Powershell is not required).

Installing `pagedjs-cli` under Windows {#Pagedjs-cli}
--------------------------------------

Ensure than [Node.js and npm](#Node.js) are installed.
Open a Command Prompt and run

```
npm install -g pagedjs-cli
```

This may take some time,
as npm will probably have to install a lot of dependencies.
If you prefer to use Powershell, you may also need to adjust the execution
policy.

You can verify that `pagedjs-cli` is installed by
running

```
pagedjs-cli --help
```

If you now create a small correct HTML file called `test.html` and run

```
pagedjs-cli test.html -o test.pdf
```

and test.pdf is created without errors, your installation
is good.
