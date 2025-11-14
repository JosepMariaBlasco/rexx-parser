The Method.Directive class
==========================

--------------------------

The Method.Directive class creates objects which
represent the `::METHOD` directives of a ooRexx program.

Superclass: [Rexx.Directive](../)

Methods of the Method.Directive class
-------------------------------------

### delegateName

![delegateName](Method.Directive.delegateName.svg) \

Returns the name of the object that should act as a delegate (a string element or a symbol element),
or `.Nil` if the `DELEGATE` keyword has not been used when specifying this directive.

### extends (Experimental)

![extends](Method.Directive.extends.svg) \

Returns the possibly namespace-qualified name of the class this method is extending,
as a two-element array. The first item of the array is a symbol element containing
the namespace, or `.Nil` when no namespace was specified. The second item is a string element
or a symbol element containing the class to be extended.
Returns `.Nil` when the `EXTENDS` keyword was not specified.

### external

![external](Method.Directive.external.svg) \

Returns a string containing the _spec_ that identifies the method in an external library,
or `.Nil` if the method is not external.

### isAbstract

![isAbstract](Method.Directive.isAbstract.svg) \

Returns `.true` when the method is an abstract method, otherwise returns `.false`.

### isAttribute

![isAttribute](Method.Directive.isAttribute.svg) \

Returns `.true` when the method is an attribute method, otherwise returns `.false`.

### isClassMethod

![isClassMethod](Method.Directive.isClassMethod.svg) \

Returns `.true` when the method is a class method. Otherwise returns `.false`.

`Note`: We are using `isClassMethod` instead of `class` because a
built-in method named `class` already exists.

### isGuarded

![isGuarded](Method.Directive.isGuarded.svg) \

Returns `.true` when the method is a guarded method, otherwise returns `.false`.

### isPackage

![isPackage](Method.Directive.isPackage.svg) \

Returns `.true` when the method is a package-scope method, otherwise returns `.false`.

### isPrivate

![isPrivate](Method.Directive.isPrivate.svg) \

Returns `.true` when the method is a private method, otherwise returns `.false`.

### isProtected

![isProtected](Method.Directive.isProtected.svg) \

Returns `.true` when the method is a protected method. Returns `.false`
for unprotected methods.

### method

![method](Method.Directive.method.svg) \

Returns the Rexx.Method object associated to this directive.

### method= {#methodEquals}

![methodEquals](Method.Directive.methodEquals.svg) \

Assigns a value that can be later retrieved by using the `method` object.

### name

![name](Method.Directive.name.svg) \

Returns the name of the method, as a string element or a symbol element.

### overrides (Experimental)

![overrides](Method.Directive.overrides.svg) \

Returns the possibly namespace-qualified name of the class this method is overriding,
as a two-element array. The first item of the array is a symbol element
containing the namespace, or `.Nil` when no namespace was specified.
The second item is a string element or a symbol element containing
the name of the class to be overrided.
Returns `.Nil` when the `OVERRIDES` keyword was not specified.
