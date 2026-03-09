return {
    "OXY2DEV/markview.nvim",
    lazy = false,

    -- Completion for `blink.cmp`
    -- dependencies = { "saghen/blink.cmp" },
    config = function()
        require("markview").setup()

        vim.keymap.set("n", "<leader>md", "<cmd>Markview toggle<CR>")
    end
}
