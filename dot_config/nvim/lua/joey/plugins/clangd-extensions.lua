return {
    "p00f/clangd_extensions.nvim",
    dependncies = {
        "neovim/nvim-lspconfig",
    },
    config = function ()
        vim.keymap.set("n", "<leader>k", ":ClangdSwitchSourceHeader<CR>")
    end
}
