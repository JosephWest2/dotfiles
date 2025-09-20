return {
    { 'navarasu/onedark.nvim' },
    config = function()
        require('onedark').setup {
            style = 'cool',
            colors = {
                bg0 = '#21262f',
            },
        }
        require('onedark').load()
    end,
    lazy = false
}
