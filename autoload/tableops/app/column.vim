scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim

" Column operations on the buffer: each takes a target from
" tableops#app#table#target(), changes a copy of its table, writes back the
" lines that differ and puts the cursor back on its cell.
" Result: {'ok', 'code', 'changed', ...}; nothing here reports.

" Render {table}, write it over {tgt} and put the cursor on cell {idx} of
" its line when the cursor was in the table. Nothing is written when the
" result would read back as another table (code 'ambiguous').
function! s:apply(tgt, table, idx) abort
  let l:new = tableops#app#table#render(a:table)
  if !l:new.ok
    return l:new
  endif
  let l:w = tableops#app#table#write(a:tgt.start, a:tgt.lines, l:new.lines)
  if !l:w.ok
    return l:w
  endif
  if a:tgt.cursor_idx >= 0 && a:idx >= 0
    call tableops#app#table#place(line('.'), a:idx)
  endif
  return {'ok': 1, 'code': '', 'changed': l:w.changed}
endfunction

function! s:ncols(tgt) abort
  return len(a:tgt.table.align)
endfunction

" Where the cursor cell {c} is after the columns {idxs} are deleted from a
" table of {n} columns: the same cell, or the cell now at its place (the
" last one when it was the last).
function! s:after_delete(c, idxs, n) abort
  if a:c < 0
    return -1
  endif
  let l:left = len(filter(copy(a:idxs), 'v:val < a:c'))
  return min([a:c - l:left, a:n - len(a:idxs) - 1])
endfunction

" Delete the columns {idxs} (0-based, no duplicates).
function! tableops#app#column#delete(tgt, idxs) abort
  let l:n = s:ncols(a:tgt)
  if len(a:idxs) >= l:n
    return {'ok': 0, 'code': 'all_columns'}
  endif
  return s:apply(a:tgt, tableops#domain#column#delete(a:tgt.table, a:idxs),
        \ s:after_delete(a:tgt.cursor_idx, a:idxs, l:n))
endfunction

" Insert an empty column right of column {idx} (left with {before}).
function! tableops#app#column#insert(tgt, idx, before) abort
  let l:pos = a:before ? a:idx : a:idx + 1
  let l:c = a:tgt.cursor_idx
  return s:apply(a:tgt, tableops#domain#column#insert(a:tgt.table, l:pos),
        \ l:c < 0 ? -1 : l:pos <= l:c ? l:c + 1 : l:c)
endfunction

" Move the cursor column by {delta} (negative: left), stopping at the
" edges. The cursor goes with it. Already at the edge: code 'edge' (ok).
function! tableops#app#column#move(tgt, delta) abort
  let l:c = a:tgt.cursor_idx
  if a:delta == 0
    return {'ok': 1, 'code': '', 'changed': 0}
  endif
  " clamped first: c + delta must not overflow
  let l:n = s:ncols(a:tgt)
  let l:delta = a:delta > l:n ? l:n : a:delta < -l:n ? -l:n : a:delta
  let l:to = max([0, min([l:c + l:delta, l:n - 1])])
  if l:to == l:c
    return {'ok': 1, 'code': 'edge', 'changed': 0}
  endif
  return s:apply(a:tgt, tableops#domain#column#move(a:tgt.table, l:c, l:to), l:to)
endfunction

" Sort the rows by column {idx}. {opts}: {numeric, icase, reverse}. The
" cursor stays on the same line and column (D4).
function! tableops#app#column#sort(tgt, idx, opts) abort
  if len(a:tgt.table.rows) <= 1
    return {'ok': 1, 'code': '', 'changed': 0}
  endif
  return s:apply(a:tgt, tableops#domain#column#sort(a:tgt.table, a:idx, a:opts),
        \ a:tgt.cursor_idx)
endfunction

function! tableops#app#column#pattern(tgt, idx) abort
  return {'ok': 1, 'code': '', 'pattern': tableops#domain#column#pattern(a:idx)}
endfunction

" '1:name  2:年齢  3:(empty)': the header, or the first row of a table
" without one.
function! tableops#app#column#columns(tgt) abort
  let l:t = a:tgt.table
  let l:cells = empty(l:t.header) ? get(l:t.rows, 0, []) : l:t.header
  let l:words = map(copy(l:cells), '(v:key + 1) . ":" . (v:val ==# "" ? "(empty)" : v:val)')
  return {'ok': 1, 'code': '', 'text': join(l:words, '  ')}
endfunction

" Byte column of the character before byte {col} of {line} (col itself at
" the start of the line).
function! s:char_before(line, col) abort
  if a:col <= 1
    return a:col
  endif
  return a:col - strlen(matchstr(strpart(a:line, 0, a:col - 1), '\m.$'))
endfunction

" Screen columns [first, last] of the character at byte {col} of {line}.
function! s:vcols(line, col) abort
  let l:first = strdisplaywidth(strpart(a:line, 0, a:col - 1)) + 1
  let l:char = matchstr(a:line, '\m.', a:col - 1)
  let l:w = l:char ==# '' ? 1 : strdisplaywidth(l:char, l:first - 1)
  return [l:first, l:first + max([l:w, 1]) - 1]
endfunction

" Delete the columns under the Visual selection (call it from x mode with
" <Cmd>). The columns are found by screen column at both ends of the
" selection; with CTRL-V by the block's left and right screen columns on
" both end lines. Visual mode is always left first, as d does; a count is
" ignored. The cursor end counts as the cursor cell.
" The kind of Visual mode is read from visualmode() after leaving it:
" mode() is not reliable in every setup (always 'ce' in Ex mode, vim -e).
function! tableops#app#column#delete_visual() abort
  if mode() =~# '\m^[niR]'
    return {'ok': 0, 'code': 'not_visual'}
  endif
  let l:v = getpos('v')
  let l:c = getpos('.')
  let l:dollar = getcurpos()[4] >= 2147483647
  execute "normal! \<Esc>"
  let l:mode = visualmode()
  let l:rv = tableops#domain#table#range(l:v[1])
  let l:rc = tableops#domain#table#range(l:c[1])
  if empty(l:rv) && empty(l:rc)
    return {'ok': 0, 'code': 'not_table'}
  elseif l:rv != l:rc
    return {'ok': 0, 'code': 'range'}
  endif
  let l:lines = getline(l:rc[0], l:rc[1])
  let l:p = tableops#domain#table#parse(l:lines)
  if !l:p.ok
    return l:p
  endif
  let l:n = len(l:p.table.align)
  let l:vline = getline(l:v[1])
  let l:cline = getline(l:c[1])
  let l:ccol = l:c[2]
  let l:exclusive = &selection ==# 'exclusive' && l:mode !=# 'V'
  if l:mode ==# "\<C-v>"
    let l:vv = s:vcols(l:vline, l:v[2])
    if l:exclusive && s:vcols(l:cline, l:ccol)[0] > l:vv[0]
      let l:ccol = s:char_before(l:cline, l:ccol)
    endif
    let l:cv = s:vcols(l:cline, l:ccol)
    let l:left = min([l:vv[0], l:cv[0]])
    let l:right = max([l:vv[1], l:cv[1]])
    " a right edge on a | is the cell on its left (but a block one column
    " wide is its left edge)
    let l:end = l:right > l:left
    let l:idxs = []
    for l:line in [l:vline, l:cline]
      call add(l:idxs, tableops#domain#table#vcell_index(l:line, l:left))
      call add(l:idxs, l:dollar ? l:n - 1 : tableops#domain#table#vcell_index(l:line, l:right, l:end))
    endfor
  else
    let l:after = l:c[1] > l:v[1] || l:c[1] == l:v[1] && l:ccol > l:v[2]
    if l:exclusive && l:after
      let l:ccol = s:char_before(l:cline, l:ccol)
    endif
    " the end that comes later in the buffer counts a | as the cell on its
    " left, the other end as the cell on its right; one character selected
    " is a start. With V the ends are cursor positions, not ends.
    let l:vend = l:mode !=# 'V' && !l:after && (l:c[1] < l:v[1] || l:ccol < l:v[2])
    let l:cend = l:mode !=# 'V' && l:after && (l:c[1] > l:v[1] || l:ccol > l:v[2])
    let l:idxs = [
          \ tableops#domain#table#vcell_index(l:vline, s:vcols(l:vline, l:v[2])[0], l:vend),
          \ tableops#domain#table#vcell_index(l:cline, s:vcols(l:cline, l:ccol)[0], l:cend)]
  endif
  let l:idxs = range(min(l:idxs), max(l:idxs))
  if len(l:idxs) >= l:n
    return {'ok': 0, 'code': 'all_columns'}
  endif
  let l:tgt = {'start': l:rc[0], 'end': l:rc[1], 'lines': l:lines, 'table': l:p.table,
        \ 'cursor_idx': tableops#domain#table#cell_index(l:cline, l:c[2])}
  return s:apply(l:tgt, tableops#domain#column#delete(l:p.table, l:idxs),
        \ s:after_delete(l:tgt.cursor_idx, l:idxs, l:n))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
