return {
    'nvim-treesitter/nvim-treesitter',
    config = function()
        require('nvim-treesitter.configs').setup {
            sync_install = false,
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            }
        }

        --vim.api.nvim_set_hl(0, "@tag.jsx", { fg = "#61afef", bold = false }) -- HTML-like tags in JSX (e.g. <div>)
        --vim.api.nvim_set_hl(0, "@tag.tsx", { fg = "#61afef", bold = false }) -- HTML-like tags in TSX
    end,
    lazy = false
}
