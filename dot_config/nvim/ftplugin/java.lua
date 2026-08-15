local root_dir = vim.fs.root(0, { "gradlew", "mvnw", ".git" })
if not root_dir then
    return
end

local workspace_dir = vim.fs.joinpath(
    vim.fn.stdpath("cache"),
    "jdtls",
    vim.fn.sha256(root_dir)
)
vim.fn.mkdir(workspace_dir, "p")

local config = {
    name = "jdtls",
    cmd = {
        "jdtls",
        "-data",
        workspace_dir,
    },
    root_dir = root_dir,
    capabilities = require("blink.cmp").get_lsp_capabilities(),
    settings = {
        java = {
            configuration = {
                updateBuildConfiguration = "interactive",
            },
        },
    },
    init_options = {
        bundles = {},
    },
    on_attach = function(_, bufnr)
        local function map(mode, lhs, rhs, description)
            vim.keymap.set(mode, lhs, rhs, {
                buffer = bufnr,
                desc = description,
            })
        end

        local jdtls = require("jdtls")
        map("n", "<leader>jo", jdtls.organize_imports, "Java: organize imports")
        map("n", "<leader>jv", jdtls.extract_variable, "Java: extract variable")
        map("v", "<leader>jv", function()
            jdtls.extract_variable(true)
        end, "Java: extract variable")
        map("n", "<leader>jc", jdtls.extract_constant, "Java: extract constant")
        map("v", "<leader>jc", function()
            jdtls.extract_constant(true)
        end, "Java: extract constant")
        map("v", "<leader>jm", function()
            jdtls.extract_method(true)
        end, "Java: extract method")
        map("n", "<leader>ju", "<cmd>JdtUpdateConfig<cr>", "Java: update project config")
    end,
}

require("jdtls").start_or_attach(config)
