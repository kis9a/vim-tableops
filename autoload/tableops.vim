scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim

" Public API. Argument checks, and the only place that reports: every
" command function returns its Result after reporting an error once.

let s:usage = {
      \ 'move': 'usage: TableopsMoveColumn {N}',
      \ 'sort': 'usage: TableopsSortColumn[!] [N] [n][i]',
      \ 'insert': 'give one column number',
      \ 'search': 'give one column number',
      \ }

function! s:error_text(r, cmd) abort
  let l:code = a:r.code
  if l:code ==# 'not_table'
    return get(a:r, 'in_range', 0) ? 'no table in range' : 'not in a table'
  elseif l:code ==# 'range'
    return a:cmd ==# 'visual' ? 'selection must be inside one table' : 'range must be inside one table'
  elseif l:code ==# 'bad_column'
    return a:r.arg =~# '\m^\d\+$'
          \ ? printf('no column %s (the table has %d)', a:r.arg, a:r.n)
          \ : 'column must be a number: ' . a:r.arg
  elseif l:code ==# 'all_columns'
    return 'cannot delete every column'
  elseif l:code ==# 'bad_args'
    return get(s:usage, a:cmd, 'bad arguments')
  elseif l:code ==# 'malformed'
    return 'the table starts with a separator row'
  elseif l:code ==# 'crlf'
    return 'CR line endings: try :e ++ff=dos'
  elseif l:code ==# 'not_modifiable'
    return '''modifiable'' is off (E21)'
  elseif l:code ==# 'ambiguous'
    return 'result would change the table structure'
  elseif l:code ==# 'not_visual'
    return 'not in Visual mode'
  endif
  " vim_error: the exception without its 'Vim(cmd):' part
  return substitute(get(a:r, 'error', l:code), '\m^Vim\%((\a\+)\)\=:', '', '')
endfunction

" Report {r} and return it with 'changed' (0 when it has none: a failure
" changed nothing).
function! s:report(r, cmd) abort
  call extend(a:r, {'changed': 0}, 'keep')
  if !a:r.ok
    call tableops#compat#notify#error(s:error_text(a:r, a:cmd))
  elseif get(a:r, 'code', '') ==# 'edge'
    call tableops#compat#notify#info('column is already at the edge')
  endif
  return a:r
endfunction

function! s:fail(code, ...) abort
  let l:r = {'ok': 0, 'code': a:code}
  if a:0
    call extend(l:r, a:1)
  endif
  return l:r
endfunction

" The column (0-based) of {tgt} that {args} names (one number at most), or
" the cursor column when {args} is blank: {'ok': 1, 'idx'} or a failure.
function! s:one_column(tgt, args) abort
  let l:words = split(a:args)
  if empty(l:words)
    return a:tgt.cursor_idx < 0 ? s:fail('not_table') : {'ok': 1, 'idx': a:tgt.cursor_idx}
  elseif len(l:words) > 1
    return s:fail('bad_args')
  endif
  let l:p = tableops#domain#column#parse_columns(l:words[0], len(a:tgt.table.align))
  if !l:p.ok
    return s:fail(l:p.code, {'arg': l:p.arg, 'n': len(a:tgt.table.align)})
  endif
  return {'ok': 1, 'idx': l:p.idxs[0]}
endfunction

" Column {count} (1-based) of {tgt}, or the cursor column for count 0.
function! s:count_column(tgt, count) abort
  return s:one_column(a:tgt, a:count ? string(a:count) : '')
endfunction

" ---- Format ------------------------------------------------------------------

function! tableops#format(line1, line2, range) abort
  return s:report(tableops#app#format#format(a:line1, a:line2, a:range), 'format')
endfunction

" Format the table of line {lnum}; silent (for autocmds).
function! tableops#format_at(lnum) abort
  return tableops#app#format#format_at(a:lnum)
endfunction

" ---- Delete ------------------------------------------------------------------

" :[range]TableopsDeleteColumn [N ...]
function! tableops#delete_column(line1, line2, range, args) abort
  let l:tgt = tableops#app#table#target(a:line1, a:line2, a:range)
  if !l:tgt.ok
    return s:report(l:tgt, 'delete')
  endif
  if empty(split(a:args))
    if l:tgt.cursor_idx < 0
      return s:report(s:fail('not_table'), 'delete')
    endif
    let l:idxs = [l:tgt.cursor_idx]
  else
    let l:n = len(l:tgt.table.align)
    let l:p = tableops#domain#column#parse_columns(a:args, l:n)
    if !l:p.ok
      return s:report(s:fail(l:p.code, {'arg': l:p.arg, 'n': l:n}), 'delete')
    endif
    let l:idxs = l:p.idxs
  endif
  return s:report(tableops#app#column#delete(l:tgt, l:idxs), 'delete')
endfunction

" [count]<Plug>(tableops-delete-column): count 0 is the cursor column.
function! tableops#delete_column_count(count) abort
  let l:tgt = tableops#app#table#target(line('.'), line('.'), 0)
  if !l:tgt.ok
    return s:report(l:tgt, 'delete')
  endif
  let l:c = s:count_column(l:tgt, a:count)
  if !l:c.ok
    return s:report(l:c, 'delete')
  endif
  return s:report(tableops#app#column#delete(l:tgt, [l:c.idx]), 'delete')
endfunction

" x mode <Plug>(tableops-delete-column).
function! tableops#delete_column_visual() abort
  return s:report(tableops#app#column#delete_visual(), 'visual')
endfunction

" ---- Insert ------------------------------------------------------------------

" :[range]TableopsInsertColumn[!] [N]
function! tableops#insert_column(line1, line2, range, before, args) abort
  let l:tgt = tableops#app#table#target(a:line1, a:line2, a:range)
  if !l:tgt.ok
    return s:report(l:tgt, 'insert')
  endif
  let l:c = s:one_column(l:tgt, a:args)
  if !l:c.ok
    return s:report(l:c, 'insert')
  endif
  return s:report(tableops#app#column#insert(l:tgt, l:c.idx, a:before), 'insert')
endfunction

function! tableops#insert_column_count(count, before) abort
  let l:tgt = tableops#app#table#target(line('.'), line('.'), 0)
  if !l:tgt.ok
    return s:report(l:tgt, 'insert')
  endif
  let l:c = s:count_column(l:tgt, a:count)
  if !l:c.ok
    return s:report(l:c, 'insert')
  endif
  return s:report(tableops#app#column#insert(l:tgt, l:c.idx, a:before), 'insert')
endfunction

" ---- Move --------------------------------------------------------------------

" :TableopsMoveColumn {N}: move the cursor column N columns (negative:
" left), stopping at the edges.
function! tableops#move_column(arg) abort
  let l:delta = tableops#domain#column#parse_delta(a:arg)
  if l:delta is v:null
    return s:report(s:fail('bad_args'), 'move')
  endif
  let l:tgt = tableops#app#table#target(line('.'), line('.'), 0)
  if !l:tgt.ok
    return s:report(l:tgt, 'move')
  endif
  return s:report(tableops#app#column#move(l:tgt, l:delta), 'move')
endfunction

" ---- Sort --------------------------------------------------------------------

" :[range]TableopsSortColumn[!] [N] [n][i]
function! tableops#sort_column(line1, line2, range, reverse, args) abort
  let l:tgt = tableops#app#table#target(a:line1, a:line2, a:range)
  if !l:tgt.ok
    return s:report(l:tgt, 'sort')
  endif
  let l:n = len(l:tgt.table.align)
  let l:p = tableops#domain#column#parse_sort_args(a:args, l:n)
  if !l:p.ok
    return s:report(s:fail(l:p.code, {'arg': l:p.arg, 'n': l:n}), 'sort')
  endif
  let l:idx = l:p.idx
  if l:idx < 0
    if l:tgt.cursor_idx < 0
      return s:report(s:fail('not_table'), 'sort')
    endif
    let l:idx = l:tgt.cursor_idx
  endif
  return s:report(tableops#app#column#sort(l:tgt, l:idx,
        \ {'numeric': l:p.numeric, 'icase': l:p.icase, 'reverse': a:reverse}), 'sort')
endfunction

" ---- Search ------------------------------------------------------------------

" The search pattern of the column at byte {col} of line {lnum}, or '' when
" the line is not in a table. Silent.
function! tableops#column_pattern(lnum, col) abort
  if empty(tableops#domain#table#range(a:lnum))
    return ''
  endif
  return tableops#domain#column#pattern(
        \ tableops#domain#table#cell_index(getline(a:lnum), a:col))
endfunction

" The command that puts the pattern of column {idx} in @/, in the history
" and turns on v:hlsearch. It must run outside a function: v:hlsearch set in
" a function is restored when the function returns (F2).
function! s:search_command(idx) abort
  return printf('let @/ = %s | call histadd("/", @/) | let v:hlsearch = 1',
        \ string(tableops#app#column#pattern({}, a:idx).pattern))
endfunction

" :[range]TableopsSearchColumn [N]: the command to :execute, or '' after an
" error.
function! tableops#search_column(line1, line2, range, args) abort
  let l:tgt = tableops#app#table#target(a:line1, a:line2, a:range)
  if !l:tgt.ok
    call s:report(l:tgt, 'search')
    return ''
  endif
  let l:c = s:one_column(l:tgt, a:args)
  if !l:c.ok
    call s:report(l:c, 'search')
    return ''
  endif
  return s:search_command(l:c.idx)
endfunction

" [count]<Plug>(tableops-search-column)
function! tableops#search_column_count(count) abort
  let l:tgt = tableops#app#table#target(line('.'), line('.'), 0)
  if !l:tgt.ok
    call s:report(l:tgt, 'search')
    return ''
  endif
  let l:c = s:count_column(l:tgt, a:count)
  if !l:c.ok
    call s:report(l:c, 'search')
    return ''
  endif
  return s:search_command(l:c.idx)
endfunction

" ---- Columns -----------------------------------------------------------------

" :[range]TableopsColumns: echo '1:name  2:年齢  3:(empty)' in full.
function! tableops#columns(line1, line2, range) abort
  let l:tgt = tableops#app#table#target(a:line1, a:line2, a:range)
  if !l:tgt.ok
    return s:report(l:tgt, 'columns')
  endif
  let l:r = tableops#app#column#columns(l:tgt)
  echo l:r.text
  return s:report(l:r, 'columns')
endfunction

" ---- Cells (<expr> mappings) -------------------------------------------------

function! tableops#notify_not_table() abort
  call tableops#compat#notify#error('not in a table')
endfunction

" {mode}: 'n', 'x', 'o', or a mode(1) value ('no...' is 'o').
function! s:mode(mode) abort
  return a:mode =~# '\m^\%(o\|no\)' ? 'o' : a:mode =~# '\m^n' ? 'n' : 'x'
endfunction

" The keys for <Plug>(tableops-cell-{dir}) in {mode}. Never ''
" in n / x: a count would stay for the next key (R2-2). In o mode the target
" is found again when the motion runs, so that . works from another place
" (R2-1); <Esc> cancels the operator when there is no target (F8).
function! tableops#cell_motion(dir, mode) abort
  let l:m = s:mode(a:mode)
  let l:pos = tableops#app#cell#target(a:dir, v:count1, l:m)
  if l:m ==# 'o'
    if empty(l:pos)
      return "\<Esc>"
    endif
    return (a:dir ==# 'up' || a:dir ==# 'down' ? 'V' : '')
          \ . printf("\<Cmd>call tableops#app#cell#go('%s', 'o')\<CR>", a:dir)
  endif
  if empty(l:pos)
    return empty(tableops#domain#table#range(line('.')))
          \ ? "\<Cmd>call tableops#notify_not_table()\<CR>" : "\<Cmd>\<CR>"
  endif
  return printf("\<Cmd>call cursor(%d, %d)\<CR>", l:pos[0], l:pos[1])
endfunction

" The keys for <Plug>(tableops-inner-cell) ({inner} 1) and
" <Plug>(tableops-a-cell) in {mode} ('x' or 'o').
function! tableops#cell_object(inner, mode) abort
  if empty(tableops#app#cell#select_range(a:inner))
    return s:mode(a:mode) ==# 'o' ? "\<Esc>" : "\<Cmd>\<CR>"
  endif
  return ":\<C-u>call tableops#app#cell#select(" . (a:inner ? 1 : 0) . ")\<CR>"
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
