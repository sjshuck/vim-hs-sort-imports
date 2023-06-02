local buffer = [[
a
b
c
]]

-- Mock API
_G.vim = {
    api = {
        nvim_get_current_buf = function() end,

        nvim_buf_get_lines = function(_, _, _, _)
            local lines = {}
            for line in buffer:gmatch("([^\n]*)\n?") do
                table.insert(lines, line)
            end
            return lines
        end,

        nvim_buf_set_lines = function(_, _, _, _, lines)
            for _, line in ipairs(lines) do
                print(line)
            end
        end,
    }
}

require('lua/hs_sort_imports').hs_sort_imports()
