Resources
=========

Data files used by the Rexx Parser at build time or run time.

- `rexxmsg.xml` — ooRexx interpreter error messages, from the ooRexx
  source tree (`main/trunk/interpreter/messages`). Used by
  `GenErrorText.rex` (in `bin/`) to generate `ANSI.ErrorText.cls`,
  and by `tests/CheckMessages.rex` for message consistency checks.

- `revision` — revision number of `rexxmsg.xml`. Used to verify
  that the message file matches the current ooRexx version.

- `UnicodeData-15.0.0.txt` — Unicode Character Database 15.0,
  character names and properties. Used by `UnicodeSupport.cls`.

- `NameAliases-15.0.0.txt` — Unicode character name aliases (15.0).
  Used by `UnicodeSupport.cls`.