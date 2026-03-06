return {
    "olimorris/codecompanion.nvim",
    version = "^19.0.0",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    config = function()
        require("codecompanion").setup({
            display = {
                chat = {
                    window = {
                        position = 'right',
                        width = 0,
                        height = 0
                    }
                },
                action_pallete = {
                    provider = 'default'
                }
            },
            interactions = {
                chat = {
                    adapter = 'opencode',
                },
                inline = {
                    adapter = 'opencode'
                },
                cmd = {
                    adapter = 'opencode'
                },
                background = {
                    adapter = 'opencode'
                }
            }
        })
        vim.keymap.set("n", "<leader>cc", "<cmd>CodeCompanionChat<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>ct", "<cmd>CodeCompanionChat Toggle<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>cs", "<cmd>CodeCompanionActions<CR>", { noremap = true, silent = true })
        vim.keymap.set("v", "<leader>ca", "<cmd>CodeCompanionChat Add<CR>", { noremap = true, silent = true })
        vim.keymap.set("v", "<leader>cc", ":CodeCompanion ")
    end
}
