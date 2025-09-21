return {
    'Exafunction/windsurf.vim',
    event = 'BufEnter',
    config = function()
        vim.g.codeium_disable_bindings = true
        vim.keymap.set('i', '<leader>a', function() return vim.fn['codeium#Accept']() end, { expr = true, silent = true })
        vim.keymap.set('i', '<leader>a', function() return vim.fn['codeium#AcceptNextWord']() end,
            { expr = true, silent = true })
        vim.keymap.set('i', '<leader>a', function() return vim.fn['codeium#AcceptNextLine']() end,
            { expr = true, silent = true })
        vim.keymap.set('i', '<c-;>', function() return vim.fn['codeium#CycleCompletions'](1) end,
            { expr = true, silent = true })
        vim.keymap.set('i', '<c-,>', function() return vim.fn['codeium#CycleCompletions'](-1) end,
            { expr = true, silent = true })
    end
}
