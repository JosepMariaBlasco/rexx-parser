PDF integration tests
=====================

Integration tests for [`md2pdf.rex`](../../bin/md2pdf.rex).
These tests exercise the PDF pipeline end-to-end: they run md2pdf
on small Markdown fixtures, then use `pdfinfo` and `pdftotext`
(from poppler-utils) to verify that the generated PDF is valid
and contains the expected content.

Unlike the unit tests in `suites/`, these tests are **not** run by
`RunTests.rex` — they require Pandoc, pagedjs-cli, and poppler-utils.


Prerequisites
-------------

- Pandoc
- Node.js and npm
- pagedjs-cli (installed via npm)
- poppler-utils (provides `pdfinfo` and `pdftotext`)
- ooRexx installed and in PATH

On Debian/Ubuntu:

```
apt-get install -y pandoc nodejs npm poppler-utils
npm install -g pagedjs-cli
```


Running the tests
-----------------

The recommended way is via the runner, which checks and offers to
install all prerequisites:

```
rexx tests/pdf/RunPDFTests.rex
```

Options:

- `--setup-only` — check/install prerequisites but do not run tests.

The tests can also be run directly (assuming prerequisites are met):

```
cd tests
PATH="framework:pdf:../bin:$PATH" rexx pdf/PDF.testGroup
```

Note: each test invokes Pandoc + pagedjs-cli, so a full run takes
around 30 seconds.


Test fixtures
-------------

All fixtures are in `fixtures/`:

| File | Purpose |
|---|---|
| `basic.md` | Simple Markdown, no docclass |
| `article.md` | `docclass: article` in YAML |
| `chapter.md` | `docclass: chapter` in YAML |
| `fenced-code.md` | Fenced code block with Rexx source |
| `section-numbers.md` | `section-numbers: true` in YAML |


What is tested (18 tests)
--------------------------

- **basic.md** (5): generates PDF, valid PDF, 1 page, correct title
  in metadata, body text present.
- **article.md** (3): generates PDF, valid PDF, body content present.
- **chapter.md** (2): generates PDF, valid PDF.
- **fenced-code.md** (3): generates PDF, valid PDF, code text present.
- **section-numbers.md** (3): generates PDF, valid PDF, content present.
- **Error handling** (1): nonexistent input file produces non-zero RC.
- **Page size** (1): PDF page size is A4.


Framework
---------

[`PDFTestCase.cls`](PDFTestCase.cls) extends `ooTestCase` with:

- **`runMd2pdf(fixture [, options])`** — runs `md2pdf.rex` on a
  fixture file. Returns a Directory with entries `rc` (return code),
  `output` (combined stdout/stderr), and `pdfFile` (path to the
  generated PDF).
- **`pdfInfo(pdfFile)`** — runs `pdfinfo` on a PDF. Returns a
  Directory with entries like `title`, `pages`, `page size`, etc.
- **`pdfText(pdfFile)`** — runs `pdftotext` on a PDF. Returns the
  extracted text as a string.
- **`assertPDF(pdfFile [, label])`** — asserts that the file exists
  and is identified as a PDF by the `file` command.
- **`assertContains(text, substring, label)`** — asserts that `text`
  contains `substring` (caseless).
- **`assertNotContains(text, substring, label)`** — asserts that
  `text` does not contain `substring` (caseless).
