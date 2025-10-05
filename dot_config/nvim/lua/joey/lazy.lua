local M = {}

local function load_plugin_config(plugin_name)
    -- Imports are relative to the lua/ directory
    local prefix = 'joey.plugins.'
    return require(prefix .. plugin_name)
end

local plugins = {
    load_plugin_config('autoclose'),
    load_plugin_config('treesitter'),
    load_plugin_config('fzf-lua'),
    load_plugin_config('auto-save'),
    load_plugin_config('onedark'),
    load_plugin_config('lspconfig'),
    load_plugin_config('lazy-dev'),
    load_plugin_config('codeium'),
    load_plugin_config('blink-cmp'),
    load_plugin_config('dap'),
    load_plugin_config('toggleterm'),
    load_plugin_config('mason'),
    load_plugin_config('overseer'),
    load_plugin_config('auto-session'),
    load_plugin_config('yazi'),
    load_plugin_config('marks'),
}

function M.init()

    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
      if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
          { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
          { out, "WarningMsg" },
          { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
      end
    end
    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
      spec = plugins,
    })

end

return M
