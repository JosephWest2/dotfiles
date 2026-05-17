return {
    'neovim/nvim-lspconfig',
    lazy = false,
    config = function()
        vim.lsp.config("*", {
            capabilities = require('blink.cmp').get_lsp_capabilities()
        })
        vim.lsp.config("gopls", {
          settings = {
            gopls = {
              semanticTokens = true,
              analyses = {
                unusedparams = true,
                shadow = true,
              },
              staticcheck = true,
            },
          },
        })
    end
}
