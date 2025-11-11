   Purpose:    create CSS files for highlight.rex (part of rexx-parser,
               https://rexx.epbcn.com/rexx-parser/) using vim (vim.org) colorschemes

               You can use any vim-colorscheme file to create a matching css file for
               rexx-parser's highlight.rex

   Usage:      procVimColors.rex vimColorSchemeFile.vim

               - copy resulting .css file to the "parser\css" directory

               - then you can use, e.g.,

                  - to highligth to ANSI terminal
                     highlight.rex -a -n -s vim-light-zellner procVimColors.rex

                  - to highlight to a HTML file
                     highlight.rex -h --css -n -s vim-light-zellner procVimColors.rex > procVimColors-vim-light-zellner.html
                     ... view procVimColors-vim-light-zellner.html in any browser

   Examples:   procVimColors.rex vimfiles/*.vim

               - uses all vim colorscheme definitions in the subdirectory "vimfiles", and
                 creates matching css files named "rexx-<style>-<stylename>.css"

               procVimColors.rex *.vim

               - creates css files for each colorscheme .vim file in the current directory,
                 and creates an appropriately named css file (e.g., "rexx-vim-light-zellner.css"
                 for "zellner.vim")

               -> copy all created css files to the "rexx-parser/css" directory

               -> to tell "highlight.rex" which color scheme to use


               - then you can use the csws files, e.g., "rexx-vim-light-zellner.css"

                  - to output to ANSI terminal

                     highlight.rex -a -n -s vim-light-zellner procVimColors.rex

                  - to output to HTML file

                     highlight.rex -h --css -n -s vim-light-zellner procVimColors.rex > procVimColors-vim-light-zellner.html

                     -> view procVimColors-vim-light-zellner.html in any browser



Vienna, 2025-11-11
