/******************************************************************************/
/* sRGB.cls - A Standard RGB class                                            */
/* ===============================                                            */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>       */
/*                                                                            */
/* NOTICE: This program is distributed as part of the Rexx Parser package,    */
/* but it can be used independently.                                          */
/*                                                                            */
/* This program provides a sRGB class that encapsulates a small part of       */
/* the CSS Color Module Level 4 definition of colours. See                    */
/* https://www.w3.org/TR/css-color-4/ for details.                            */
/*                                                                            */
/* sRGB colors can be created from three- or six-digits hexadecimal strings,  */
/* or by providing three blank-separated values, which can be percentages     */
/* ended with a "%" character, between 0 and 100, or non-necessarily integer  */
/* whole numbers between 0 and 255.                                           */
/*                                                                            */
/* The class provides conversions to:                                         */
/*   + Linear RGB                                                             */
/*   + CIE XYZ                                                                */
/*   + OKLab                                                                  */
/* and a DeltaEOK function returning the distance between any two sRGB points */
/* as measured in the OKLab color space.                                      */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20250621    0.2c First version                                             */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- Work at the maximum precision that RxMath allows (assume 64 bits), plus    --
-- two digits for rounding                                                    --
--------------------------------------------------------------------------------

::Options   Digits 18

--------------------------------------------------------------------------------
-- Load the RxMath library                                                    --
--------------------------------------------------------------------------------

::Requires 'rxmath' Library

--------------------------------------------------------------------------------
-- Provide nice names for the RxMath functions we will be using               --
--------------------------------------------------------------------------------

::Routine exp   External "LIBRARY rxmath RxCalcExp"
::Routine log   External "LIBRARY rxmath RxCalcLog"
::Routine power External "LIBRARY rxmath RxCalcPower"
::Routine sqrt  External "LIBRARY rxmath RxCalcSqrt"

--------------------------------------------------------------------------------
-- CLASS sRGB                                                                 --
--------------------------------------------------------------------------------

---
--- Represents a Standard RGB (sRGB) color value
---
--- Please note that sRGB is a _non-linear_ color space.
---

::Class sRGB Public

--------------------------------------------------------------------------------
-- METHOD INIT                                                                --
--------------------------------------------------------------------------------
---
--- Creates a sRGB color value
---
--- @param r_g_b Three blank-separated primaries, or a single three or six
---   characters hexadecimal value, with an optional leading "#" character.
---
--- When providing blank-separated primaries, each primary can be specified
--- as a number between 0 and 255, or as a percentage between 0 and 100.
--- Non-integers and exponentials are accepted.
---

::Method init

  Expose R G B

  Use Strict Arg r_g_b

  Select Case Words(r_g_b)
    When 1 Then Signal Hex
    When 3 Then Signal Three
    Otherwise   Signal OneOrThree
  End

Three:
  Parse Var r_g_b R G B .

  -- Validate and construct R, G and B

  Call Validate >R, "Red"
  Call Validate >G, "Green"
  Call Validate >B, "Blue"

  Return

Validate: Procedure
  Use Arg >value, Color
  If right(value,1) == "%" Then Do
    val = Left(value,Length(value)-1)
    If DataType(val) \== "NUM" Then Signal NoNumber
    If val < 0                 Then Signal Negative
    If val > 100               Then Signal TooBig
    value = value / 100
    Return
  End
  If DataType(value) \== "NUM" Then Signal NoNumber
  If value < 0                 Then Signal Negative
  If value > 255               Then Signal TooBig
  value = value / 255
Return

Hex:
  hex = r_g_b
  If hex[1] == "#" Then hex = SubStr(hex,2)
  Select Case Length(hex)
    When 6 Then Parse Var hex r +2 g +2 b
    When 3 Then Do
      Parse Var hex r +1 g +1 b
      R = R || R
      G = G || G
      B = B || B
    End
    Otherwise Signal BadHexLength
  End
  R = R~x2d / 255
  G = G~x2d / 255
  B = B~x2d / 255
Return

BadHexLength: Raise Syntax 93.900 -
  Array( "Argument should be a 3- or 6-digit hexadecimal number, optionally" -
    "preceded by a '#' character. Found '"r_g_b"'" )

OneOrThree: Raise Syntax 93.900 -
  Array( "One or three words expected, found '"r_g_b"'." )

NoNumber: Call 93.900 "primary should be a number or a percentage"

Negative: Call 93.900 "primary should be zero or positive"

TooBig:   Call 93.900 "primary should be smaller than 255" -
    "(or 100 if specified as a percentage)"

93.900: Raise Syntax 93.900 Array(Color Arg(1)", found '"value"'")

--------------------------------------------------------------------------------
-- METHOD MAKESTRING                                                          --
--------------------------------------------------------------------------------
---
--- Converts to a string with a certain precision (default is 2)
---
--- @param precision Optional precision, between 0 and 18.
---
--- @return A string containing the blank separated R, G, and B values,
---    formatted to the specified precision.
---

::Method makeString Public
  Expose R G B

  Use Strict Arg precision = 2

  If \DataType(precision, "W") Then Raise Syntax 93.905 Array(1, precision)
  If precision < 0             Then Raise Syntax 93.906 Array(1, precision)
  If precision > 18            Then Raise Syntax 93.908 Array(1, 18, precision)

  Return P(R) P(G) P(B)

P: Return Format( Arg(1) * 255,,precision)

--------------------------------------------------------------------------------
-- METHOD TOLINEAR                                                            --
--------------------------------------------------------------------------------
---
--- Converts a sRGB value to linear RGB
---
--- @return A string containing the linearized R, G and B primaries.
---

::Method toLinear Public

  Expose R  G  B

  Return Linear(R) Linear(G) Linear(B)

Linear:
  Use Arg primary

  If primary <= 0.04045 Then Return primary / 12.92

  t = (primary + 0.055) / 1.055
  Return Power( t, 2.4 )

--------------------------------------------------------------------------------
-- METHOD TOOKLAB                                                             --
--------------------------------------------------------------------------------
---
--- Converts a sRGB value to Oklab
---
--- @return The L, a, b components of the OKLab conversion
---
--- See function XYZ_to_OKLab(XYZ) in https://www.w3.org/TR/css-color-4/
---

::Method toOKlab Public

  -- Transform sRGB to CIE XYZ (D65)

  Parse Value self~toXYZ With X Y Z

  -- Transform to LMS

  L = 0.8190224379967030*X + 0.3619062600528904*Y  -0.1288737815209879*Z
	M	= 0.0329836539323885*X + 0.9292868615863434*Y + 0.0361446663506424*Z
	S	= 0.0481771893596242*X + 0.2642395317527308*Y + 0.6335478284694309*Z

  Lc = Power( L, 1/3 )
  Mc = Power( M, 1/3 )
  Sc = Power( S, 1/3 )

  Return                                                                  -
    0.2104542683093140*Lc + 0.7936177747023054*Mc - 0.0040720430116193*Sc -
		1.9779985324311684*Lc - 2.4285922420485799*Mc + 0.4505937096174110*Sc -
		0.0259040424655478*Lc + 0.7827717124575296*Mc - 0.8086757549230774*Sc


--------------------------------------------------------------------------------
-- METHOD TOXYZ                                                               --
--------------------------------------------------------------------------------
---
--- Convert sRGB to CIE XYZ using the D65 illuminant
---
--- @return A string containing the blank-separated X, Y and Z values
---

::Method toXYZ Public

  ------------------------------------------------------------------------------
  -- Transform sRGB to linear RGB                                             --
  ------------------------------------------------------------------------------

  Parse Value self~toLinear With R G B

  ------------------------------------------------------------------------------
  -- Convert linear RGB to XYZ                                                --
  ------------------------------------------------------------------------------

  -- See function lin_sRGB_to_XYZ(rgb) in https://www.w3.org/TR/css-color-4/

	X = 506752 * R / 1228815 +   87881 * G / 245763 +   12673 * B /   70218
	Y =  87098 * R /  409605 +  175762 * G / 245763 +   12673 * B /  175545
	Z =   7918 * R /  409605 +   87881 * G / 737289 + 1001167 * B / 1053270

  Return X Y Z

--------------------------------------------------------------------------------
-- METHOD DELTAEOK                                                            --
--------------------------------------------------------------------------------

---
--- Returns the distance between two sRGB values, as measured in the OKLab
---   color space
---
--- @param aColor The color to compare with
--- @return The OKLab DeltaE distance between this color and aColor
---    Experimentation shows that this distance ranges between 0 and 1 when
---    operating inside the sRGB color cube.
---
--- See https://www.w3.org/TR/css-color-4/#color-difference-OK
---

::Method DeltaEOK Public

  Use Strict Arg aColor

 .Validate~classType("aColor", aColor, self~class)

  Parse Value self  ~toOKLab With L1 a1 b1
  Parse Value aColor~toOKLab With L2 a2 b2

  Return sqrt( (L1-L2)**2 + (a1-a2)**2 + (b1-b2)**2 )
