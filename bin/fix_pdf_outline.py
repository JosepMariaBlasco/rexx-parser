"""
/******************************************************************************/
/*                                                                            */
/* fix_pdf_outline.py - Fixes PDF Pagemode                                    */
/* =======================================                                    */
/*                                                                            */
/* Usage: python fix_pdf_outline filename.pdf                                 */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260228    0.4a First public release                                      */
/*                                                                            */
/******************************************************************************/
"""

import pikepdf
import sys
import os

def fix_pdf_outline(file):
    if not os.path.exists(file):
        print(f"Error: File not found '{file}'")
        return

    try:
        with pikepdf.open(file, allow_overwriting_input=True) as pdf:
            # /UseOutlines shows outline, /None hides it, /UseThumbs opens thumbnails
            pdf.Root.PageMode = pikepdf.Name('/UseOutlines')
            pdf.save(file)
        sys.exit(0)
    except Exception as e:
        print(f"Error processing PDF: {e}")
        sys.exit(0)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_pdf.py filename.pdf")
    else:
        fix_pdf_outline(sys.argv[1])