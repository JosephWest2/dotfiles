return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1

        local api = require("nvim-tree.api")

        -- always focus the tree, opening it first if it is closed
        vim.keymap.set("n", "<leader>t", function()
            api.tree.open { find_file = true }
        end)

        require("nvim-tree").setup {
            update_focused_file = {
                enable = true,
            },
            view = {
                -- don't let nvim-tree run `wincmd =` and re-equalize every split
                preserve_window_proportions = true,
            },
            actions = {
                open_file = {
                    -- keep a manually resized tree instead of snapping back on open
                    resize_window = false,
                },
            },
        }
    end,
}
