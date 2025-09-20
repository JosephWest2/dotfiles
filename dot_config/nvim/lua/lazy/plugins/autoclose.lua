return {
    'm4xshen/autoclose.nvim',
    config = function()
        require('autoclose').setup({
            keys = {
                ["("] = { escape = false, close = true, pair = "()" },
                ["["] = { escape = false, close = true, pair = "[]" },
                ["{"] = { escape = false, close = true, pair = "{}" },
                [")"] = { escape = true, close = false, pair = "()" },
                ["]"] = { escape = true, close = false, pair = "[]" },
                ["}"] = { escape = true, close = false, pair = "{}" },
                ['"'] = { escape = true, close = true, pair = '""' },
                ["'"] = { escape = true, close = false, pair = "''" },
                ["`"] = { escape = true, close = true, pair = "``" },
            },
            options = {
                auto_indent = true,
            },
        })
    end,
    lazy = false,
}
