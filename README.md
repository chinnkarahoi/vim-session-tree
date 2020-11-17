## vim-session-tree
![demo](./doc/demo.gif)
This plugin is for undoing changes triggered by closing or opening windows.

### Installation
```vim
Plug 'chinnkarahoi/vim-session-tree'
```

### Usage
#### `:SessionUndo` Command
Undo changes triggered by closing or opening windows.If you open multiple windows by one action, it will close all of them, and vice versa.  

---
#### `:SessionRedo` Command
Undo `:SessionUndo`

---
#### `:SessionRestore` Command
Used with command line to restore last session that you quit vim in current working directory,
which is `vim +SessionRestore`. You can add a alias for it for convenience.

### Options
`g:session_tree_data_dir` Default: `~/.cache/vim-session-tree`  
Session files will be saved to this directory.

---
`g:session_tree_count_limit` Default: `100`  
Limit maximum session files on vim startup while redundant files will be deleted. Set to -1 to disable.

### Configuration Example
```vim
nnoremap <silent> <leader>u :<c-u>SessionUndo<cr>
nnoremap <silent> <leader>r :<c-u>SessionRedo<cr>
set updatetime=100
set nocompatible
set sessionoptions=buffers,folds,tabpages,winpos,localoptions
```
