-- Projection for partial ordering of parenthesized import items
local function item_type(item)
    if string.find("^type ", item) then
        -- Type operator
        return 1
    elseif string.find("^[A-Z]", item) then
        -- Type
        return 2
    elseif string.find("^%(", item) then
        -- Operator
        return 3
    else
        -- Function
        return 4
    end
end

-- Mutate the table of lines to do all the actual work of the plugin
local function rearrange_lines(lines)
    local cur_chunk = nil
    local last_i
    local chunks = {}

    -- Parse each line as potentially an import statement
    for i, line in ipairs(lines) do
        -- Split on spaces
        local words = {}
        for word in string.gmatch(line, "%S+") do
            table.insert(words, word)
        end

        if table.remove(words, 1) ~= "import" then
            goto continue
        end

        -- If the first line of a contiguous chunk of import statements,
        -- collect parsed line info into a new chunk table, else add to the
        -- current chunk table.
        local v = {}
        if cur_chunk == nil or last_i + 1 < i then
            cur_chunk = {
                first_i = i,
                vs = {},
            }
            table.insert(chunks, cur_chunk)
        end
        last_i = i
        table.insert(cur_chunk.vs, v)

        if words[1] == "qualified" then
            table.remove(words, 1)
            v.qualified = true
        end

        v.module = table.remove(words, 1)

        -- Anything after the module name
        local after_module = table.concat(words, " ")
        if after_module == "" then
            goto continue
        end

        -- Try to isolate parenthesized, comma-separated list of items
        local to_open_parens, in_parens, from_close_parens =
            string.match(after_module, "([^(]*%()(.*)(%).*)")
        if not in_parens then
            -- No list of items
            v.after_module = after_module
            goto continue
        end

        -- Yes list of items.  Sort it
        local items = {}
        for item in string.gmatch(in_parens, "([^,]+),? *") do
            table.insert(items, item)
        end
        table.sort(items, function(item1, item2)
            local item1_type, item2_type = item_type(item1), item_type(item2)
            if item1_type < item2_type then
                return true
            elseif item1_type > item2_type then
                return false
            end
            return item1 < item2
        end)

        v.after_module = table.concat {
            to_open_parens,
            table.concat(items, ", "),
            from_close_parens,
        }

        ::continue::
    end

    -- Individually sort every chunk of import statements
    for _, chunk in ipairs(chunks) do
        -- First by module, then by non-qualified-ness
        table.sort(chunk.vs, function(v1, v2)
            if v1.module < v2.module then
                return true
            elseif v1.module > v2.module then
                return false
            end
            return not v1.qualified and v2.qualified
        end)

        -- Determine widths of columns
        local any_qualified = false
        local max_module_len = 0
        for _, v in ipairs(chunk.vs) do
            any_qualified = any_qualified or v.qualified
            max_module_len = math.max(max_module_len, #v.module)
        end

        -- Render lines in columnar format
        for i, v in ipairs(chunk.vs) do
            local words = {"import "}
            if any_qualified then
                local qual_col = v.qualified and
                    "qualified " or
                    "          "
                table.insert(words, qual_col)
            end
            table.insert(words, v.module)
            if v.after_module then
                local num_spaces = max_module_len - #v.module + 1
                table.insert(words, string.rep(' ', num_spaces))
                table.insert(words, v.after_module)
            end

            -- Save
            lines[chunk.first_i + i - 1] = table.concat(words)
        end
    end
end

local function hs_sort_imports()
    local buf = vim.api.nvim_get_current_buf()

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

    rearrange_lines(lines)

    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
end

-- Export
return {
    hs_sort_imports = hs_sort_imports
}
