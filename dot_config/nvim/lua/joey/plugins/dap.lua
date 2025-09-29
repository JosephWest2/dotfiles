-- requires codelldb
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

-- requires dlv and kitty
local function go_setup()
    local dap_go = require('dap-go')
    dap_go.setup({
        dap_configurations = {
            {
                type = "go",
                name = "Run in Kitty and attach",
                mode = "remote",
                request = "attach",
                port = function()
                    local tcp = assert(vim.uv.new_tcp())
                    tcp:bind('127.0.0.1', 0)
                    local port = tcp:getsockname().port
                    tcp:shutdown()
                    tcp:close()
                    vim.fn.jobstart("kitty --single-instance --hold dlv debug --headless --listen=:" ..
                        port ..
                        " --api-version=2 --redirect=\"stdin:/dev/stdin\" --redirect=\"stdout:/dev/stdout\" --redirect=\"stderr:/dev/stderr\"")
                    return vim.fn.input("Enter the port number: ", "" .. port)
                end,
            },
        },
    })
end




return {
    'mfussenegger/nvim-dap',
    dependencies = {
        "rcarriga/nvim-dap-ui",
        "nvim-neotest/nvim-nio",
        'leoluz/nvim-dap-go',
        "nvim-treesitter/nvim-treesitter",
        "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
        local dap = require('dap')
        local dap_ui = require('dapui')

        require("nvim-dap-virtual-text").setup()

        dap_ui.setup()

        c_cpp_rust_setup(dap)
        go_setup()

        dap.defaults.fallback.force_external_terminal = true

        dap.listeners.before.attach.dapui_config = function(m, b)
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
        vim.keymap.set("n", "<leader>ds", function()
            dap.terminate()
            dap_ui.close()
        end)
        vim.keymap.set("n", "<leader>dc", dap.clear_breakpoints)
    end
}
