First steps
===========

-----------------------------------------------

+ Open a terminal shell in the installation directory, and
  `cd` to the [`utils`](/rexx-parser/utils/) subdirectory.
  Run the `highlight.rex` program passing `sample.html`
  as an argument:

  ```
  rexx highlight.rex ./sample.html
  ```

  You should see output similar to the following
  (line breaks have been added for readability):

  <pre>
  &lt;!doctype html&gt;&lt;html lang='en'&gt;
    &lt;head&gt;
      &lt;title&gt;Test&lt;/title&gt;
      &lt;link rel='stylesheet' href='/rexx-parser/css/rexx-dark.css'&gt;
    &lt;head&gt;
  &lt;body&gt;
  Sample text

  &lt;div class="highlight-rexx-dark"&gt;
  &lt;pre&gt;
  &lt;span class="rx-kw"&gt;If&lt;/span&gt;&lt;span class="rx-ws"&gt; &lt;/span&gt;
  &lt;span class="rx-var"&gt;a&lt;/span&gt;&lt;span class="rx-ws"&gt; &lt;/span&gt;
  &lt;span class="rx-op"&gt;=&lt;/span&gt;&lt;span class="rx-ws"&gt; &lt;/span&gt;
  &lt;span class="rx-var"&gt;b&lt;/span&gt;&lt;span class="rx-ws"&gt; &lt;/span&gt;
  &lt;span class="rx-kw"&gt;Then&lt;/span&gt;&lt;span class="rx-ws"&gt; &lt;/span&gt;
  &lt;span class="rx-var"&gt;c&lt;/span&gt;
  &lt;/pre&gt;

  Last line
  &lt;/body&gt;
  &lt;/html&gt;</pre>

+ Now look at [the source of `highlight.rex`](/rexx-parser/doc/utils/highlight/)
  and inspect `sample.html` too. You have just seen
  [the Rexx HTML highlighter](/rexx-parser/doc/highlighter/html/) in action!
+ Now, in the same directory, [run `elements.rex`](/rexx-parser/doc/utils/elements/)
  with `./hi.rex` as an argument.

  ~~~
  rexx elements ./hi.rex
  ~~~

  You should see output similar to the following:

  <pre>
  elements.rex run on 15 Feb 2025 at 10:54:37

  Examining hi.rex...

  Elements marked '&gt;' are inserted by the parser.
  Elements marked 'X' are ignorable.
  Compound symbol components are distinguished with a '-&gt;' mark.

  [   from  :    to   ] &gt;X 'value' (class)
   --------- ---------  -- ---------------------------
  [    1   1:    1   1] &gt;  ';' (a EL.END_OF_CLAUSE)
  [    1   1:    1   4]    'SAY' (a EL.KEYWORD)
  [    1   4:    1   5]  X ' ' (a EL.WHITESPACE)
  [    1   5:    1   9]    'Hi' (a EL.STRING)
  [    1   9:    1   9] &gt;  ';' (a EL.END_OF_CLAUSE)
  [    1   9:    1   9] &gt;  '' (a EL.IMPLICIT_EXIT)
  [    1   9:    1   9] &gt;  ';' (a EL.END_OF_CLAUSE)
  [    1   9:    1   9] &gt;  '' (a EL.END_OF_SOURCE)
  [    1   9:    1   9] &gt;  ';' (a EL.END_OF_CLAUSE)
  Total: 9 elements and 0 compound symbol elements examined.
  </pre>

+ You can now browse [the Rexx Highligther](/rexx-parser/doc/highlighter/) page,
  if you please, where you will find several new programs to run.
+ If you want to implement your own Rexx highlighter (recommended! :)),
  you will find a nice utility to do so in the
  [Highligther](/rexx-parser/doc/highlighter/) page.
  You will also need some CSS files. The ones I am using in this site
  (which are fairly incomplete, specially the light background one!)
  can be found in the `css` subdirectory.
+ Take a look at [the HTML Highlighter](/rexx-parser/doc/highlighter/html/) page,
  and follow the links there, specially the
  [features](/rexx-parser/doc/highlighter/features/) one.
+ For a beautiful highlighting example of a medium-sized (~750 lines)
  source program, see [this program](/rexx-parser/doc/ref/categories/),
  which defines all the element categories, category sets and subcategories.
+ Take a look at the documentation about [the Element API](/rexx-parser/doc/guide/elementapi/).
+ And, finally... please give feedback! Your feedback is important.
  Seriously! :) You can reach me at <josep.maria.blasco@epbcn.com>.