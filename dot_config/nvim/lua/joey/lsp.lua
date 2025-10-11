local M = {}

function M.init()
    vim.lsp.enable('clangd')
    vim.lsp.enable('lua_ls')
    vim.lsp.enable('gopls')
    vim.lsp.enable('rust_analyzer')

    vim.diagnostic.config({
        virtual_lines = {
            current_line = true
        }
    })
end

return M
