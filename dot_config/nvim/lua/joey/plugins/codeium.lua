return {
    'Exafunction/windsurf.vim',
    event = 'BufEnter',
    config = function()
        vim.g.codeium_disable_bindings = true
        vim.g.codeium_idle_delay = 150
        vim.keymap.set('i', '<C-j>', function() return vim.fn['codeium#Accept']() end, { expr = true, silent = true })
        vim.keymap.set('i', '<C-h>', function() return vim.fn['codeium#AcceptNextWord']() end,
            { expr = true, silent = true })
        vim.keymap.set('i', '<C-l>', function() return vim.fn['codeium#AcceptNextLine']() end,
            { expr = true, silent = true })
        vim.keymap.set('i', '<C-;>', function() return vim.fn['codeium#CycleCompletions'](1) end,
            { expr = true, silent = true })
        vim.keymap.set('i', '<C-,>', function() return vim.fn['codeium#CycleCompletions'](-1) end,
            { expr = true, silent = true })
        vim.keymap.set('n', '<leader>ae', function()
            vim.cmd('Codeium Enable')
            print('autosuggestions enabled')
        end)
        vim.keymap.set('n', '<leader>ad', function()
            vim.cmd('Codeium Disable')
            print('autosuggestions disabled')
        end)
    end
}
