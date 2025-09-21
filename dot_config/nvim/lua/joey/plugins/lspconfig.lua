return {
    'neovim/nvim-lspconfig',
    lazy = false,
    config = function()
        local capabilities = require('blink.cmp').get_lsp_capabilities()
    end
}
