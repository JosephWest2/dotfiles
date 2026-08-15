return {
    "mason-org/mason-lspconfig.nvim",
    opts = {
        ensure_installed = {
            "jdtls",
        },
        automatic_enable = {
            exclude = {
                "jdtls",
            },
        },
    },
    dependencies = {
        "mason-org/mason.nvim",
        "neovim/nvim-lspconfig",
    },
}
