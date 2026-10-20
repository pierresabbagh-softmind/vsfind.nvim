# vsfind.nvim

A find box for Neovim, inspired by the Visual Studio Code search box.

It opens a small floating input at the top-right of the window, highlights matches as you type, shows an
"N of M" count and has case / whole-word / regex toggles.

## Features

- Live search and highlighting while typing
- Match count (`3 of 42`), capped at `999+` to stay fast on large files
- Toggles for match case (`Aa`), whole word (`ab`) and regex (`.*`), remembered for the session
- Seeds the query from a single-line visual selection
- Opens folds around the current match
- Leaves the pattern in the search register and history, so `n` / `N` keep working after closing

## Requirements

- Neovim 0.10+

## Installation

[vim.pack](https://neovim.io/doc/user/pack.html#vim.pack) (Neovim 0.12+):

```lua
vim.pack.add({ 'https://github.com/sabbaghpierre/vsfind.nvim' })
vim.keymap.set({ 'n', 'x' }, '/', require('vsfind').open, { desc = 'Find in buffer' })
```

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'sabbaghpierre/vsfind.nvim',
  keys = {
    { '/', function() require('vsfind').open() end, mode = { 'n', 'x' }, desc = 'Find in buffer' },
  },
}
```

vsfind does not create any mappings itself; bind `require('vsfind').open` to whatever key you like.

## Usage

Press your mapping and start typing. In visual mode, the selection is used as the initial query.

| Key                 | Action                    |
| ------------------- | ------------------------- |
| `<CR>` / `<C-n>`    | Next match                |
| `<S-CR>` / `<C-p>`  | Previous match            |
| `<M-c>`             | Toggle match case         |
| `<M-w>`             | Toggle whole word         |
| `<M-r>`             | Toggle regex              |
| `<Esc>`             | Close                     |

`q` also closes from normal mode, and so does moving focus out of the box. The cursor stays on the match. Use `<C-o>` to jump back to where the search started.

Notes:

- Many terminals send `<S-CR>` as a plain `<CR>`; use `<C-p>` there.
- On macOS, the `<M-…>` toggles need the terminal to treat Option as Meta.

## License

[MIT](LICENSE)
