scriptencoding utf-8

let s:suite = themis#suite('plugin')
let s:assert = themis#helper('assert')

let s:root = fnamemodify(expand('<sfile>:p:h:h'), ':p')

let s:commands = ['TableopsFormat', 'TableopsDeleteColumn', 'TableopsInsertColumn',
      \ 'TableopsMoveColumn', 'TableopsSortColumn', 'TableopsSearchColumn', 'TableopsColumns']

let s:plugs = {
      \ 'format': 'n', 'delete-column': 'nx',
      \ 'insert-column-after': 'n', 'insert-column-before': 'n',
      \ 'move-column-left': 'n', 'move-column-right': 'n',
      \ 'sort-column': 'n', 'search-column': 'n', 'columns': 'n',
      \ 'cell-left': 'nxo', 'cell-right': 'nxo', 'cell-up': 'nxo', 'cell-down': 'nxo',
      \ 'inner-cell': 'xo', 'a-cell': 'xo',
      \ }

function! s:reload() abort
  unlet! g:loaded_tableops
  runtime plugin/tableops.vim
endfunction

function! s:delete_commands() abort
  for l:c in s:commands
    if exists(':' . l:c) == 2
      execute 'delcommand' l:c
    endif
  endfor
endfunction

function! s:suite.after_each() abort
  call s:delete_commands()
  silent! delcommand TableopsFormatX
  call s:reload()
endfunction

function! s:suite.commands_exist() abort
  for l:c in s:commands
    call s:assert.equals(exists(':' . l:c), 2, l:c)
  endfor
endfunction

function! s:suite.plug_mappings_exist_in_their_modes() abort
  for [l:name, l:modes] in items(s:plugs)
    for l:mode in ['n', 'x', 'o']
      let l:has = maparg('<Plug>(tableops-' . l:name . ')', l:mode) !=# ''
      call s:assert.equals(l:has, stridx(l:modes, l:mode) >= 0, l:name . ' ' . l:mode)
    endfor
  endfor
endfunction

function! s:suite.no_default_keys() abort
  let l:lines = split(execute('map') . execute('map!'), "\n")
  call filter(l:lines, 'v:val =~# "tableops"')
  call s:assert.not_empty(l:lines)
  for l:line in l:lines
    call s:assert.match(l:line, '^\S*\s\+<Plug>(tableops-')
  endfor
endfunction

function! s:suite.loaded_guard() abort
  command! TableopsColumns echo 'mine'
  runtime plugin/tableops.vim
  call s:assert.equals(execute('TableopsColumns'), "\nmine")
endfunction

function! s:suite.an_existing_command_is_kept() abort
  call s:delete_commands()
  command! TableopsColumns echo 'mine'
  call s:reload()
  call s:assert.equals(execute('TableopsColumns'), "\nmine")
  for l:c in s:commands
    call s:assert.equals(exists(':' . l:c), 2, l:c)
  endfor
endfunction

function! s:suite.sort_mapping_only_with_our_command() abort
  call s:delete_commands()
  nunmap <Plug>(tableops-sort-column)
  command! -nargs=* -bang TableopsSortColumn echo 'mine'
  call s:reload()
  call s:assert.equals(maparg('<Plug>(tableops-sort-column)', 'n'), '')
  call s:delete_commands()
  call s:reload()
  call s:assert.not_equals(maparg('<Plug>(tableops-sort-column)', 'n'), '')
endfunction

function! s:suite.a_longer_command_name_does_not_count() abort
  call s:delete_commands()
  command! TableopsFormatX echo 'other'
  call s:assert.equals(exists(':TableopsFormat'), 1)
  call s:reload()
  call s:assert.equals(exists(':TableopsFormat'), 2)
endfunction

" :helptags on a copy of doc/ (no tags file in the repository): no E154.
function! s:suite.helptags() abort
  let l:dir = tempname()
  call mkdir(l:dir . '/doc', 'p')
  try
    call writefile(readfile(s:root . 'doc/tableops.txt', 'b'), l:dir . '/doc/tableops.txt', 'b')
    execute 'helptags' fnameescape(l:dir . '/doc')
    let l:tags = readfile(l:dir . '/doc/tags')
    for l:tag in [':TableopsFormat', 'tableops-limitations', '<Plug>(tableops-a-cell)']
      call s:assert.not_empty(filter(copy(l:tags), 'stridx(v:val, l:tag . "\t") == 0'), l:tag)
    endfor
  finally
    call delete(l:dir, 'rf')
  endtry
endfunction

function! s:suite.every_message_fits_50_columns() abort
  " the texts of s:error_text() (autoload/tableops.vim) without arguments
  for l:msg in ['not in a table', 'no table in range', 'range must be inside one table',
        \ 'selection must be inside one table', 'cannot delete every column',
        \ 'the table starts with a separator row', 'CR line endings: try :e ++ff=dos',
        \ '''modifiable'' is off (E21)', 'result would change the table structure',
        \ 'not in Visual mode', 'column is already at the edge',
        \ 'usage: TableopsMoveColumn {N}', 'usage: TableopsSortColumn[!] [N] [n][i]',
        \ 'give one column number', 'no column 10 (the table has 9)']
    call s:assert.true(strdisplaywidth('[tableops] ' . l:msg) <= 50, l:msg)
    call s:assert.equals(tableops#compat#notify#text(l:msg), '[tableops] ' . l:msg)
  endfor
endfunction

function! s:suite.minimum_version_guard() abort
  " Vim 9.0 / Neovim 0.9: older versions finish before g:loaded_tableops is
  " set and before anything is defined
  let l:src = readfile(s:root . 'plugin/tableops.vim')
  let l:guard = index(l:src, "if !has('nvim-0.9') && v:version < 900")
  call s:assert.true(l:guard > 0)
  call s:assert.equals(l:src[l:guard + 1 : l:guard + 2], ['  finish', 'endif'])
  call s:assert.true(l:guard < index(l:src, 'let g:loaded_tableops = 1'))
  call s:assert.true(index(l:src, 'if exists(''g:loaded_tableops'')') < l:guard)
endfunction
