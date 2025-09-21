local M = {}

local prefix = "joey.lsp."

function M.init()
    require(prefix .. "clangd").init()
    require(prefix .. "lua_ls").init()

    vim.diagnostic.config({
        virtual_lines = {
            current_line = true
        }
    })
end

return M
