
Say ".Methods[Floating]=".Methods[Floating]
Say "Method A has disappeared from the .METHODS stringtable"
Say ".Methods[A]       =".Methods[A]
Say "The translated method name has also disappeared"
Say ".Methods['M<+>X:CLASS1']=".Methods['M<+>X:CLASS1']
Say "Class AClass does not have methods called M or O"
Say "M:" HasMethod(.AClass, "M")
Say "O:" HasMethod(.AClass, "O")
Say "Creating a CLASS1 object..."
o = .Class1~new
Say "Invoking CLASS1 method A..."
o~a
Say "Invoking CLASS1 method M..."
o~m
Say "Invoking CLASS1 method O..."
o~o

Exit

HasMethod: Signal On Syntax Name StrangeAPI

  throwAway = Arg(1)~method( Arg(2) )
  Return 1

StrangeAPI: Return 0

-- A floating method
::Method Floating

-- An floating extension method. It will be removed from .METHODS
::Method A Extends Class1
  Say "Class1 method A called"

::Class AClass

-- An extension method. It will be removed from class AClass
::Method M Extends X:Class1
  Say "Class1 method M called"

-- An overriding extension method. It will be removed from class AClass
::Method O Overrides Class1
  Say "Replaced method called"

::Requires "extended.cls" namespace X