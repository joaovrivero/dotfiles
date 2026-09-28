return {
  -- Pinacoteca is generated from a base16 palette; see colors/pinacoteca.lua
  { "nvim-mini/mini.base16", lazy = false, priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "pinacoteca",
    },
  },
}
