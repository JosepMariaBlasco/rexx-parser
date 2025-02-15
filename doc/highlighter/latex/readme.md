The (Lua)LaTeX Highlighter
==========================

------------------------------

Package dependencies
--------------------

The current version of the LuaLaTeX highlighter
is based on the following packages:

- `xcolor`, for basic color support.
- `lua-ul`, for proper background highlighting.
- `listings`, to hold the listings themselves.
- `tcolorbox`, to fix an annoying problem with extra space
  appearing between listing lines in some circumstances.

Fonts
-----

The default mono font does not support boldface. If you need
boldface in your highlighting schemas (the default ones supplied
with the Rexx Parser use boldface), you should use a different
mono font. The Hack font, for example, available at
<https://sourcefoundry.org/hack/>, seems to produce decent
results.

Listing width
-------------

You will most probably need to adjust the size of your font,
depending on the page size and the number of characters
you want displayed on the largest line. The following style
definition allows for exactly 80 characters per line,
when using the Hack font and an A4 paper size:

~~~tex
\lstdefinestyle{rexx}
{
	basicstyle=\fontsize{8.0pt}{11.0pt}\selectfont\color{white}\ttfamily
}
~~~

Commands
--------

The LuaLaTeX highlighting framework defines a single command. The
exclamation mark is being used as an escape character,
and the command is needed when the exclamation
appears in a Rexx program.

~~~tex
\newcommand{\textexclamup}{!}
~~~

Selecting LaTeX mode
--------------------

The `-l` and `--latex` options of the
[*highlight*](/rexx.parser/doc/utils/highlight/) utility
will select the LuaLaTeX highlighter. The highlighter output
will be a complete `lstlisting` environment.

Example output
--------------

~~~tex
\begin{lstlisting}[ style=rexx, frame=single, escapechar=!, backgroundcolor={\color[HTML]{000000}} ]
!\textcolor[HTML]{cccc00}{~~}\textcolor[HTML]{ffcc00}{\textit{.environment}}\textcolor[HTML]{ff0000}{\~{}}\textcolor[HTML]{b8fa5c}{\textit{test.2.x}}\textcolor[HTML]{cccc00}{~}\textcolor[HTML]{dddddd}{\textbf{=}}\textcolor[HTML]{cccc00}{~}\textcolor[HTML]{ff66ff}{test.}\textcolor[HTML]{33cccc}{2}\textcolor[HTML]{ff0000}{.}\textcolor[HTML]{ff66ff}{\textit{x}}\textcolor[HTML]{cccc00}{~~~~~~}\textcolor[HTML]{00cc00}{\textit{--~Method~call,~compound~variable...}}!
!\textcolor[HTML]{cccc00}{~~}\textcolor[HTML]{dddddd}{\textbf{Exit}}\textcolor[HTML]{cccc00}{~}\textcolor[HTML]{ffcc00}{\textit{.test.2.x}}\textcolor[HTML]{cccc00}{~~~~~~~~~~~~~~~~~~~~~~~~}\textcolor[HTML]{00cc00}{\textit{--~...and~environment~variable}}!
\end{lstlisting}
~~~

An complete sample Tex file
---------------------------

~~~tex
\documentclass[12pt,a4paper,english]{article}
\usepackage{xcolor}
\usepackage{lua-ul}
\usepackage{fontspec}
\setmonofont{Hack}
\usepackage{listings}
\usepackage[many]{tcolorbox}

\lstdefinestyle{rexx}
{
	basicstyle=\fontsize{8.0pt}{11.0pt}\selectfont\color{white}\ttfamily
}

\begin{document}

\newcommand{\textexclamup}{!}

\begin{lstlisting}[ style=rexx, frame=single, escapechar=!, backgroundcolor={\color[HTML]{000000}} ]
!\textcolor[HTML]{cccc00}{~~}\textcolor[HTML]{ffcc00}{\textit{.environment}}\textcolor[HTML]{ff0000}{\~{}}\textcolor[HTML]{b8fa5c}{\textit{test.2.x}}\textcolor[HTML]{cccc00}{~}\textcolor[HTML]{dddddd}{\textbf{=}}\textcolor[HTML]{cccc00}{~}\textcolor[HTML]{ff66ff}{test.}\textcolor[HTML]{33cccc}{2}\textcolor[HTML]{ff0000}{.}\textcolor[HTML]{ff66ff}{\textit{x}}\textcolor[HTML]{cccc00}{~~~~~~}\textcolor[HTML]{00cc00}{\textit{--~Method~call,~compound~variable...}}!
!\textcolor[HTML]{cccc00}{~~}\textcolor[HTML]{dddddd}{\textbf{Exit}}\textcolor[HTML]{cccc00}{~}\textcolor[HTML]{ffcc00}{\textit{.test.2.x}}\textcolor[HTML]{cccc00}{~~~~~~~~~~~~~~~~~~~~~~~~}\textcolor[HTML]{00cc00}{\textit{--~...and~environment~variable}}!
\end{lstlisting}

\end{document}
~~~