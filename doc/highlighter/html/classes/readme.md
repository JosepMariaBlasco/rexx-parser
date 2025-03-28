Element categories to HTML class mappings
=========================================

----------------------------------------

Every *element category*, and, in the case of
elements which are "taken constants" (that is,
strings or symbols taken as a constant),
every *element subcategory*, is eventually associated
with a *HTML class*. The form of this association
is determined by the values specified in
the argument stem. The following package contains
the routine implementing the default HTML class mapping.

```rexx {source=../../../../bin/HTMLClasses.cls}
```