return {
    "sindrets/diffview.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
        { "<leader>gv", "<cmd>DiffviewOpen<CR>", desc = "Git: Open diff view" },
        { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Git: Close diff view" },
        { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Git: File history" },
        { "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Git: Repository history" },
    },
    opts = {},
}
