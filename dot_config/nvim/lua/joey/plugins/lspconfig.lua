return {
    'neovim/nvim-lspconfig',
    lazy = false,
    config = function()
        vim.lsp.config("*", {
            capabilities = require('blink.cmp').get_lsp_capabilities()
        })
    end
}
