local M = {}

function M.init()
    vim.lsp.enable('clangd')
    vim.lsp.enable('lua_ls')
    vim.lsp.enable('gopls')

    vim.diagnostic.config({
        virtual_lines = {
            current_line = true
        }
    })
end

return M
