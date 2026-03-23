CGI integration tests
=====================

Integration tests for [`CGI.markdown.rex`](../../cgi/CGI.markdown.rex).
These tests exercise the CGI pipeline end-to-end via Apache + curl:
they start an HTTP request, pass it through Apache to the CGI handler,
and verify the generated HTML output.

Unlike the unit tests in `suites/`, these tests are **not** run by
`RunTests.rex` — they require a running Apache instance with the
CGI pipeline configured.


Prerequisites
-------------

- Apache 2 with `cgid` and `actions` modules
- Pandoc
- ooRexx installed and in PATH

On Debian/Ubuntu:

```
apt-get install -y apache2 pandoc
a2enmod cgid actions
```


Apache configuration
--------------------

Create `/etc/apache2/sites-available/rexx-cgi.conf` (adjust
`DocumentRoot` and paths to match your project location):

```apache
<VirtualHost *:80>
    DocumentRoot /path/to/project
    <Directory /path/to/project>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ScriptAlias /cgi-bin/ /path/to/project/cgi/
    <Directory /path/to/project/cgi>
        Options +ExecCGI
        AllowOverride None
        Require all granted
        SetHandler cgi-script
    </Directory>
    Action Markdown /cgi-bin/cgi-wrapper.sh
    <FilesMatch "\.(md|rex|cls)$">
        SetHandler Markdown
    </FilesMatch>
</VirtualHost>
```

The wrapper script `cgi/cgi-wrapper.sh` sets `REXX_PATH` and invokes
the CGI handler:

```bash
#!/bin/bash
export REXX_PATH="/path/to/project/cgi:/path/to/project/bin"
exec rexx /path/to/project/cgi/CGI.markdown.rex "$@"
```

Enable the site and start Apache:

```
a2dissite 000-default
a2ensite rexx-cgi
chmod +x /path/to/project/cgi/cgi-wrapper.sh
chmod +x /path/to/project/cgi/CGI.markdown.rex
apachectl start
```

Note: `.rex` and `.cls` are included in `FilesMatch` so that
`view=highlight` works for Rexx source files.


Running the tests
-----------------

With Apache running:

```
cd tests
PATH="framework:cgi:../bin:$PATH" rexx cgi/CGI.testGroup
```

The tests use `http://127.0.0.1` as the base URL (not `localhost`,
to avoid DNS/proxy issues). The base URL is set via the class-level
`baseURL` attribute, initialized in `activate`.


Test fixtures
-------------

All fixtures are in `fixtures/`:

| File | Purpose |
|---|---|
| `basic.md` | Simple Markdown, no YAML front matter |
| `with-yaml.md` | YAML: language, highlight-style, section-numbers |
| `docclass-article.md` | `docclass: article` in YAML |
| `docclass-chapter.md` | `docclass: rexxdoc-chapter`, `chapter: 5` |
| `rexx-code.md` | Fenced code block with Rexx source |
| `hello.rex` | Rexx source file for `view=highlight` tests |


What is tested (39 tests)
--------------------------

- **Basic response** (8): status 200, HTML structure, title extraction,
  default language, default stylesheets.
- **YAML options** (3): language, highlight-style, section-numbers.
- **Docclass article** (3): rexxpub-base.css, article.css, no
  markdown.css.
- **Docclass rexxdoc-chapter** (5): rexxpub-base.css,
  rexxdoc-chapter.css, data-chapter attribute, chapter label,
  default section-numbers.
- **Fenced code** (3): highlight div, keyword classes, theme CSS.
- **URL param style** (2): style=light changes highlight class and CSS.
- **URL param print=pdf** (8): paged.polyfill.js inclusion,
  print-specific CSS loading for basic (no docclass), article,
  and rexxdoc-chapter.
- **Invalid parameters** (1): unknown param returns 404.
- **Nonexistent file** (1): returns 404.
- **view=highlight** (5): .rex with highlight, without highlight,
  invalid view value.


Framework
---------

[`CGITestCase.cls`](CGITestCase.cls) extends `ooTestCase` with:

- **`httpGet(url)`** — performs an HTTP GET via curl, returns a
  Directory with `status` (HTTP status code) and `body` (response
  text).
- **`assertContains(text, substring, label)`** — asserts that
  `text` contains `substring` (caseless).
- **`assertNotContains(text, substring, label)`** — asserts that
  `text` does not contain `substring` (caseless).