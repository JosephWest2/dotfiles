-- Requires vscode-cpptools extension installed and the binary OpenDebugAD7 pointed to by command
local function c_cpp_rust_setup(dap)
    dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
            command = "codelldb",
            args = { "--port", "${port}" },
        },
    }
    dap.configurations.c = dap.configurations.cpp
    dap.configurations.rust = dap.configurations.cpp
end

return {
    'mfussenegger/nvim-dap',
    dependencies = {
        "rcarriga/nvim-dap-ui",
        "leoluz/nvim-dap-go",
        "nvim-neotest/nvim-nio",
        "nvim-treesitter/nvim-treesitter",
        "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
        local dap = require('dap')
        local dap_ui = require('dapui')

        dap.defaults.fallback.external_terminal = {
            command = "/usr/bin/kitty",
            args = { "--single-instance", "--detach" },
            cwd = vim.fn.getcwd(),
        }

        require("nvim-dap-virtual-text").setup()
        require("dap-go").setup()

        dap_ui.setup()

        c_cpp_rust_setup(dap)

        dap.listeners.before.attach.dapui_config = function()
            dap_ui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dap_ui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dap_ui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dap_ui.close()
        end
        dap.listeners.before.disconnect.dapui_config = function()
            dap_ui.close()
        end

        vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint)
        vim.keymap.set("n", "<leader>B", function() dap.toggle_breakpoint(vim.fn.input("Breakpoint condition: ")) end)
        vim.keymap.set("n", "<leader>dn", dap.continue)
        vim.keymap.set("n", "<leader>di", dap.step_into)
        vim.keymap.set("n", "<leader>do", dap.step_over)
        vim.keymap.set("n", "<leader>du", dap.step_out)
        vim.keymap.set("n", "<leader>ds", dap.terminate)
        vim.keymap.set("n", "<leader>dc", dap.clear_breakpoints)
    end
}
