function! s:join(...) abort
  if has('win32')
    let sep = '\'
  else
    let sep = '/'
  endif
  return join(a:000, sep)
endfunction
function! s:get_path() abort
  if has('win32')
    return substitute(getcwd(), '[\:]', '@', 'g')
  else
    return substitute(getcwd(), '/', '@', 'g')
  endif
endfunction
function! s:get_timestamp() abort
  return printf("%030s", localtime() . '.' . float2nr(reltimefloat(reltime()) * 1000000) % 1000000)
endfunction

let g:session_tree_data_dir = get(g:, 'session_tree_data_dir', s:join($HOME, '.cache', 'vim-session-tree'))
let g:session_tree_count_limit = get(g:, 'session_tree_count_limit', 100)
let g:session_tree_vimleave_record = get(g:, 'session_tree_vimleave_record', 1)

let s:session_tree_dir = s:join(g:session_tree_data_dir, s:get_path())
if !isdirectory(s:session_tree_dir)
  call mkdir(s:session_tree_dir, 'p')
endif

let s:tree = {}
let s:tree.cur_node = '0'
let s:tree.next = {}
let s:tree.parent = {}
function! s:tree.insert(x, y) abort
  let self.parent[a:y] = a:x
  let self.next[a:x] = a:y
endfunction
function! s:makefile(x, y) abort
  return s:join(s:session_tree_dir, a:x . "-" . a:y)
endfunction
function! s:tree.init() abort
  let session_list=sort(split(glob(s:session_tree_dir . '/*'), '\n'))
  if g:session_tree_count_limit >= 0
    let remove_count = len(session_list) - g:session_tree_count_limit
    if remove_count > 0
      for i in range(remove_count)
        call delete(session_list[i])
      endfor
      call remove(session_list, 0, remove_count - 1)
    endif
  endif
  for i in range(len(session_list))
    let nodes = split(fnamemodify(session_list[i],':t'), '-')
    if len(nodes) != 2
      continue
    endif
    let [y, x] = nodes
    if len(y) < 30
      continue
    endif
    call self.insert(x,y)
    let self.cur_node = y
  endfor
endfunction
function! s:tree.get_parent(...) abort
  let x = self.cur_node
  if a:0 > 0
    let x = a:1
  endif
  if has_key(self.parent, x)
    return self.parent[x]
  else
    return '0'
  endif
endfunction
function! s:tree.get_next(...) abort
  let x = self.cur_node
  if a:0 > 0
    let x = a:1
  endif
  if has_key(self.next, x)
    return self.next[x]
  else
    return ''
  endif
endfunction
function! s:tree.get_file(...) abort
  if a:0 == 0
    return s:makefile(self.cur_node, self.get_parent())
  endif
  return s:makefile(a:1, self.get_parent(a:1))
endfunction
let s:session_tree_exists_bufname = ['[Command Line]']
function! s:check_exists() abort
  for i in range(1,tabpagenr('$'))
    for j in tabpagebuflist(i)
      if index(s:session_tree_exists_bufname, bufname(j)) >= 0
        return v:true
      endif
    endfor
  endfor
  return v:false
endfunction
function! s:tree.make_session(increase) abort
  if s:check_exists()
    return
  endif
  let session_filepath = self.get_file()
  if a:increase > 0 || self.cur_node == '0' || !filereadable(session_filepath)
    let new_node = s:get_timestamp()
    let session_filepath = s:makefile(new_node, self.cur_node)
    call self.insert(self.cur_node, new_node)
    let self.cur_node = new_node
  endif
  exec "mksession! " . session_filepath
endfunction
let g:close_unlisted_ignored_filetype = get(g:, 'close_unlisted_ignored_filetype', ['tagbar'])
let g:enable_close_unlisted = get(g:, 'enable_close_unlisted', 1)
function! s:close_unlisted() abort
  let ret = 0
  for i in range(1,tabpagenr('$'))
    for j in tabpagebuflist(i)
      if len(getbufinfo(j)) == 0 || !has_key(getbufinfo(j)[0], 'listed') || getbufinfo(j)[0]['listed'] == 0
        if index(g:close_unlisted_ignored_filetype, getbufvar(j, '&filetype')) < 0 && tabpagenr() == i
          let ret = 1
        endif
        exec "bd " . j
      endif
    endfor
  endfor
  return ret
endfunction
function! s:check_status() abort
  if exists('#goyo')
    Goyo
    return v:false
  endif
  if g:enable_close_unlisted == 1
    let ret = s:close_unlisted()
    if ret == 1
      return v:false
    endif
  endif
  return v:true
endfunction
function! s:tree.restore_session(...) abort
  if !s:check_status()
    return v:false
  endif
  let x = self.cur_node
  if a:0 > 0
    let x = a:1
  endif
  let session_filepath = self.get_file(x)
  if !filereadable(session_filepath)
    echo 'no more session'
    return v:false
  endif
  try
    call s:toggle_buf_session(0)
    silent tabonly
    silent only
    enew
    exec "silent source " . session_filepath
  catch
    return v:false
  finally
    call s:count_restorable_buffers()
    call s:toggle_buf_session(1)
  endtry
  return v:true
endfunction
function! s:tree.undo_session(...) abort
  if !s:check_status()
    return
  endif
  let y = self.cur_node
  let x = self.get_parent(y)
  if self.restore_session(x)
    let self.next[x] = y
    let self.cur_node = x
  endif
endfunction
function! s:tree.redo_session(...) abort
  if !s:check_status()
    return
  endif
  let y = self.get_next()
  if self.restore_session(y)
    let self.cur_node = y
  endif
endfunction
function! s:tree.vimleave() abort
  if g:session_tree_vimleave_record == 1
    if self.get_next() != ''
      call self.make_session(1)
    endif
  endif
endfunction
call s:tree.init()
let g:session_tree_restore = 0
let s:buffer_count_old = 0
let s:buffer_count = 0
function! s:count_restorable_buffers() abort
  let s:buffer_count_old = s:buffer_count
  let s:buffer_count = 0
  for i in range(1,tabpagenr('$'))
    for j in tabpagebuflist(i)
      if len(getbufinfo(j)) > 0 && has_key(getbufinfo(j)[0], 'listed') && &buftype != 'terminal'
        let s:buffer_count += getbufinfo(j)[0]['listed'] * ((bufname(j) !='') + 1)
      endif
    endfor
  endfor
  return s:buffer_count
endfunction
let s:session_increase = 0
let s:session_restore_set = 0
let g:session_tree_bufwin_filetype = get(g:, 'session_tree_bufwin_filetype', ['git'])
function! s:toggle_buf_session(arg)
  if a:arg == 1
    augroup SessionTree
      autocmd!
      autocmd VimEnter * doautocmd SessionTree CursorHold
      autocmd BufWinEnter,BufWinLeave *
            \ if index(g:session_tree_bufwin_filetype, &filetype) >= 0 |
            \   let s:session_increase = 1 |
            \ endif |
      autocmd CursorHold *
            \ call s:count_restorable_buffers() |
            \ if s:buffer_count > 1 && !exists('#goyo')|
            \   if s:buffer_count_old != s:buffer_count |
            \     call s:tree.make_session(1) |
            \   elseif len(getbufinfo('%')) > 0 && has_key(getbufinfo('%')[0], "listed") && getbufinfo('%')[0]['listed'] == 1 |
            \     call s:tree.make_session(s:session_increase) |
            \   endif |
            \ endif |
            \ let s:session_increase = 0 |
      autocmd VimLeavePre * call s:tree.vimleave()
    augroup END
  else
    augroup SessionTree
      autocmd!
    augroup END
  endif
endfunction
call s:toggle_buf_session(1)
command! SessionRestore call s:tree.restore_session()
command! SessionUndo call s:tree.undo_session()
command! SessionRedo call s:tree.redo_session()
