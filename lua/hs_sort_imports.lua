-- Projection for partial ordering of parenthesized import items
local function item_type(item)
    if string.find(item, "^type ") then
        -- Type operator
        return 1
    elseif string.find(item, "^[A-Z]") then
        -- Type
        return 2
    elseif string.find(item, "^%(") then
        -- Operator
        return 3
    else
        -- Function
        return 4
    end
end

local handlers = {
    pragma = {
        parse = function(line)
            if not string.find(line, "^%S") then
                return nil
            end

            local words = {}
            for word in string.gmatch(line, "%S+") do
                table.insert(words, word)
            end

            if #words < 3 or words[1] ~= "{-#" or words[#words] ~= "#-}" then
                return nil
            end

            -- Pragma type
            words[2] = string.upper(words[2])

            return table.concat(words, " ")
        end,

        sort = table.sort,
    },

    import = {
        parse = function(line)
            if not string.find(line, "^%S") then
                return nil
            end

            local words = {}
            for word in string.gmatch(line, "%S+") do
                table.insert(words, word)
            end

            if table.remove(words, 1) ~= "import" then
                return nil
            end
            local parsed = {}

            if words[1] == "qualified" then
                table.remove(words, 1)
                parsed.qualified = true
            end

            parsed.module = table.remove(words, 1)

            -- Anything after the module name
            if #words == 0 then
                return parsed
            end
            local after_module = table.concat(words, " ")

            -- Try to isolate parenthesized, comma-separated list of items
            local to_open_parens, in_parens, from_close_parens =
                string.match(after_module, "([^(]*%()(.*)(%).*)")
            if not in_parens then
                -- No list of items
                parsed.after_module = after_module
                return parsed
            end

            -- Yes list of items.  Sort it
            local items = {}
            for item in string.gmatch(in_parens, "([^,]+),? *") do
                table.insert(items, item)
            end
            table.sort(items, function(item1, item2)
                local item1_type = item_type(item1)
                local item2_type = item_type(item2)
                if item1_type < item2_type then
                    return true
                elseif item1_type > item2_type then
                    return false
                else
                    return item1 < item2
                end
            end)

            parsed.after_module = table.concat {
                to_open_parens,
                table.concat(items, ", "),
                from_close_parens,
            }

            return parsed
        end,

        sort = function(chunk)
            -- First by module, then by non-qualified-ness
            table.sort(chunk, function(v1, v2)
                if v1.module < v2.module then
                    return true
                elseif v1.module > v2.module then
                    return false
                else
                    return not v1.qualified and v2.qualified
                end
            end)

            -- Determine widths of columns
            local any_qualified = false
            local max_module_len = 0
            for _, parsed in ipairs(chunk) do
                any_qualified = any_qualified or parsed.qualified
                max_module_len = math.max(max_module_len, #parsed.module)
            end

            -- Render lines in columnar format
            for i, v in ipairs(chunk) do
                local cols = {"import"}
                if any_qualified then
                    local qual_col = v.qualified and
                        "qualified" or
                        "         "
                    table.insert(cols, qual_col)
                end
                table.insert(cols, v.module)
                if v.after_module then
                    local spaces = string.rep(" ", max_module_len - #v.module)
                    table.insert(cols, spaces .. v.after_module)
                end

                chunk[i] = table.concat(cols, " ")
            end
        end,
    },
}

-- Returns a function that when called gets the next tuple
--     (parsed data, type of data)
local function parse_lines(lines)
    return coroutine.wrap(function()
        for _, line in ipairs(lines) do
            -- An unparsable line will yield (the line, nil)
            local v, v_type = line, nil

            for handler_name, handler in pairs(handlers) do
                local parsed = handler.parse(line)
                if parsed then
                    v, v_type = parsed, handler_name
                    break
                end
            end

            coroutine.yield(v, v_type)
        end
    end)
end

-- A chunk is a table of contiguous parsed lines of the same type, tagged with
-- the name of the handler that parsed it and will sort it.
local function chunks_and_lines(vs_with_types)
    return coroutine.wrap(function()
        local chunk = {}

        for v, v_type in vs_with_types do
            if #chunk > 0 and v_type ~= chunk.type then
                -- End of chunk
                coroutine.yield(chunk)
                chunk = {}
            end

            if v_type then
                if #chunk == 0 then
                    -- Beginning of chunk
                    chunk.type = v_type
                    chunk.sort = handlers[v_type].sort
                end
                table.insert(chunk, v)
            else
                -- Unparsed line
                coroutine.yield(v)
            end
        end

        if #chunk > 0 then
            -- Final chunk
            coroutine.yield(chunk)
        end
    end)
end

local function process_lines(old_lines)
    local vs = parse_lines(old_lines)
    local new_lines = {}

    for chunk_or_line in chunks_and_lines(vs) do
        if type(chunk_or_line) == "table" then
            -- Chunk
            chunk_or_line:sort()
            for _, line in ipairs(chunk_or_line) do
                table.insert(new_lines, line)
            end
        else
            -- Line
            table.insert(new_lines, chunk_or_line)
        end
    end

    return new_lines
end

-- Export
return {
    hs_sort_imports = function()
        local buf = vim.api.nvim_get_current_buf()

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

        lines = process_lines(lines)

        vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    end,
}
