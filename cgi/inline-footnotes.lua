--------------------------------------------------------------------------------
--                                                                            --
-- inline-footnotes.lua - Pandoc Lua filter to place footnotes at page end    --
-- =======================================================================    --
--                                                                            --
-- This program is part of the Rexx Parser package                            --
-- [See https://rexx.epbcn.com/rexx-parser/]                                  --
--                                                                            --
-- Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  --
--                                                                            --
-- License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  --
--                                                                            --
-- Version history:                                                           --
--                                                                            --
-- Date     Version Details                                                   --
-- -------- ------- --------------------------------------------------------- --
-- 20250217    0.4a First version                                             --
--                                                                            --
--------------------------------------------------------------------------------

-- Lua filter to place footnotes at page end
function Note(el)
    local inlines = pandoc.List()
    for _, block in ipairs(el.content) do
        if block.content then
            inlines:extend(block.content)
            inlines:insert(pandoc.Space())
        end
    end
    -- We keep the class so Paged.js moves it, but we stay out of Pandoc's way
    return pandoc.Span(inlines, {class="footnote"})
end
