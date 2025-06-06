/******************************************************************************/
/******************************************************************************/
/*                                                                            */
/* CIELAB.CLS                                                                 */
/*                                                                            */
/* "CIE" is the International Commission on Illumination.                     */
/* "CIELAB", or "L*a*b*", is a color space defined by the CIE.                */
/*                                                                            */
/* CIELAB was intended as a perceptually uniform space,                       */
/* where a given numerical change corresponds                                 */
/* to a similar perceived change in color.                                    */
/*                                                                            */
/* All the algorithms used here are public: see the references in the code.   */
/*                                                                            */
/* This program has been written by                                           */
/*    Josep Maria Blasco <josep.maria.blasco@epbcn.com>                       */
/*                                                                            */
/******************************************************************************/
/******************************************************************************/

::Requires 'rxmath' LIBRARY             -- Load our dependencies

/******************************************************************************/
/* DeltaE -- a synonym for ΔE*                                                */
/******************************************************************************/

::Routine DeltaE Public
  Use Strict Arg rgb1, rgb2
  Return "ΔE*"(rgb1, rgb2)

/******************************************************************************/
/* ΔE* -- A CIELAB distance                                                   */
/*                                                                            */
/* Delta is a Greek letter often used to denote difference, and E stands      */
/* for Empfindung; German for "sensation" [Wikipedia].                        */
/*                                                                            */
/******************************************************************************/

::Routine "ΔE*" Public

  -- See https://en.wikipedia.org/wiki/Color_difference#CIELAB_%CE%94E*

  Use Strict Arg rgb1, rgb2

  Parse Value RGB2Lab(rgb1) With L1 a1 b1
  Parse Value RGB2Lab(rgb2) With L2 a2 b2

  Return RxCalcSqrt( (L1 - L2)**2 + (a1 - a2)** 2 + (b1- b2)**2 )

/******************************************************************************/
/* RGB2Lab -- Convert RGB to CIELAB                                           */
/******************************************************************************/

::Routine RGB2Lab Public

  -- See https://en.wikipedia.org/wiki/SRGB
  -- See https://github.com/cxx5208/Rgb-to-LAB
  -- See http://colorizer.org
  -- See https://gramaz.io/d3-jnd/
  --
  -- This algorithm is using the D65 Standard illuminant
  --

  ------------------------------------------------------------------------------
  -- Validate arguments                                                       --
  ------------------------------------------------------------------------------

  If Arg(1)~isA(.Array) Then Do         -- An array (R, G, B)
    Use Strict Arg V
    R = V[1]
    G = V[2]
    B = V[3]
  End
  Else If Arg() == 1 Then Do            -- A string "R G B"
   .Validate~classType("1", Arg(1), .String)
    Parse Arg R G B
  End
  Else Use Strict Arg R, G, B           -- Three args: R, G, B

 .Validate~WholeNumberRange("R", R, 0, 255)
 .Validate~WholeNumberRange("G", G, 0, 255)
 .Validate~WholeNumberRange("B", B, 0, 255)

  ------------------------------------------------------------------------------
  -- Normalize R, G and B                                                     --
  ------------------------------------------------------------------------------

  R = Gamma(R / 255) * 100
  G = Gamma(G / 255) * 100
  B = Gamma(B / 255) * 100

  ------------------------------------------------------------------------------
  -- Convert RGB to XYZ                                                       --
  ------------------------------------------------------------------------------

  -- See https://www.cs.rit.edu/~ncs/color/t_convert.html

  X = R * 0.412453 + G * 0.357580 + B * 0.180423
  Y = R * 0.212671 + G * 0.715160 + B * 0.072169
  Z = R * 0.019334 + G * 0.119193 + B * 0.950227

  ------------------------------------------------------------------------------
  -- Convert to L*a*b*                                                        --
  ------------------------------------------------------------------------------

  fX = f(X /  95.047)
  fY = f(Y / 100.000)
  fZ = f(Z / 108.883)

  L = Format(116 *  fY - 16 , , 2)
  a = Format(500 * (fX - fY), , 2)
  b = Format(200 * (fY - fZ), , 2)

Return L a b

--------------------------------------------------------------------------------

-- Compute x**y for real values of y as exp(y*log(x)).
Power: Return RxCalcExp( Arg(2) * RxCalcLog( Arg(1) ) )

--------------------------------------------------------------------------------

f: Procedure
  Use Arg W

  If W <= 0.008856 Then Return W * 7.787 + 16 / 116
  Return Power(W, 1/3)

--------------------------------------------------------------------------------

Gamma: Procedure
  Use Arg primary

  If primary <= 0.04045 Then Return primary / 12.92

  t = (primary + 0.055) / 1.055
  Return Power(t, 2.4)
