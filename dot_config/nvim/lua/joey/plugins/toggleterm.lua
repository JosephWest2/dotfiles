return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
        require("toggleterm").setup({
            direction = "float",
            open_mapping = [[<leader>t]],
        })
    end
}
