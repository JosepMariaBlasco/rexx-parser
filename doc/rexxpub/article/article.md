Writing articles with <br> RexxPub, a Rexx Publishing Framework <small>A subtitle</small>{.title}
===============================================================

## [Josep Maria Blasco](https://www.epbcn.com/equipo/josep-maria-blasco/) {.author}
## Espacio Psicoanalítico de Barcelona {.affiliation}
## Balmes, 32, 2º 1ª &mdash; 08007 Barcelona {.address}
## jose.maria.blasco@gmail.com {.email}
## +34 93 454 89 78 {.phone}


Page configuration
------------------

+ DIN A4, portrait orientation.
+ Contents uses Times New Roman, if available.
+ Font size is 12pt.
+ Paragraphs are justified, and hypenation is used when available.

The title block
---------------

### Title

Use a header with a class of `title`:

```
Writing articles with RexxPub, a Rexx Publishing Framework {.title}
==========================================================
```

# Writing articles with RexxPub, a Rexx Publishing Framework {.title}

---

### Subtitles

Enclose the subtitle between `<small>` and `</small>`
inside the title

```
This is the title <small>and this is the subtitle</small> {.title}
---------------------------------------------------------
```

This is the title <small>and this is the subtitle</small> {.title}
---------------------------------------------------------

### Author

Use a header with a class of `author`:

```
## Josep Maria Blasco {.author}

```

## Josep Maria Blasco {.author}

### Affiliation and address

Use  headers with classes `affiliation` and `address`,
respectively:

```
### Espacio Psicoanalítico de Barcelona       {.affiliation}
### Balmes, 32, 2º 1ª &mdash; 08007 Barcelona {.address}
```

### Espacio Psicoanalítico de Barcelona       {.affiliation}
### Balmes, 32, 2º 1ª &mdash; 08007 Barcelona {.address}


### Email

Use a header with a class of `email`:

```
### josep.maria.blasco@epbcn.com {.email}
```

### josep.maria.blasco@epbcn.com {.email}


### Phone

Use a header with a class of `phone`:

```
### +34 93 454 89 78 {.phone}
```

### +34 93 454 89 78 {.phone}

### Date

Use a header with a class of `date`:

```
## February 18, 2026 {.date}
```

## February 18, 2026 {.date}
