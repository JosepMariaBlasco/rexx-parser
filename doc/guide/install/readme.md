Installation
============

-----------------------------------------------

Prerequisites
-------------

- A working ooRexx 5.0 installation.
- If you intend to install [CGI support](/rexx-parser/cgi/),
  you will also need a working Apache installation with
  access to ooRexx 5.0 and to Pandoc (Apache 2.4 is recommended).

Installation
------------

+ Go to [the downloads section](/rexx-parser/#download) of the
  [main Parser page](/rexx-parser/),
  download the most current version of [the Rexx Parser](/rexx-parser/), and
  unzip it in a directory of your choice.
+ You can also install the Rexx Parser as part of the
  **net-oo-rexx** software bundle. The net-oo-rexx package
  can be downloaded at
  <https://wi.wu.ac.at/rgf/rexx/tmp/net-oo-rexx-packages/>.

### CGI installation

For a [CGI installation](/rexx-parser/cgi/), follow these steps:

+ In your Apache configuration, define an
  [action directive](https://httpd.apache.org/docs/2.4/mod/mod_actions.html)
  pointing to your version of `CGI.markdown.rex`:

      Action RexxCGIMarkdown [path]CGI.markdown.rex

+ You can then use whatever mechanism you prefer to associate
  Markdown files with the action handler you just defined.

      <Files *.md>
        SetHandler RexxCGIMarkdown
      </Files>

+ Restart Apache.


First steps: checking that your installation works
--------------------------------------------------

Proceed to the [first steps](/rexx-parser/doc/guide/first-steps/) page
to check that your installation works properly.
