return {
    'mfussenegger/nvim-dap',
    dependencies = {
        "rcarriga/nvim-dap-ui",
    },
    config = function()
        local dap = require('dap')
        vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint)
    end
}
