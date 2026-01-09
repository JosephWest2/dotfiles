local M = {}

function M.init()
    vim.lsp.enable('clangd')
    vim.lsp.enable('lua_ls')
    vim.lsp.enable('gopls')
    vim.lsp.enable('rust_analyzer')
    vim.lsp.enable('zls')
    vim.lsp.enable('templ')
    vim.lsp.enable('svelte')
    vim.g.zig_fmt_autosave = 0

    vim.diagnostic.config({
        virtual_lines = {
            current_line = true
        }
    })
end

return M
