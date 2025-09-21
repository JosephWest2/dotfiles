return {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons'},
    config = function()
        local fzf = require('fzf-lua')
        vim.keymap.set("n", "<leader>ff", function() fzf.files() end)
        vim.keymap.set("n", "<leader>gg", function() fzf.grep_project() end)

        fzf.setup({
            keymap = {
                fzf = {
                    ["ctrl-q"] = "select-all+accept"
                }
            }
        })
    end,
    lazy = false,
}
