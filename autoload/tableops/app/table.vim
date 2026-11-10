" Reading the target table, writing back only the lines that changed, and
" placing the cursor on a cell.

let s:save_cpo = &cpoptions
set cpoptions&vim

" The table to work on. With {range} 0 the table of the cursor line, else
" the table of {line1}; {line2} must be inside it.
"   {'ok': 1, 'start', 'end', 'lines', 'table', 'cursor_idx'}
"   cursor_idx: the cell (0-based) of the cursor when the cursor line is in
"   the table, else -1.
"   {'ok': 0, 'code': 'not_table' | 'range' | 'malformed' | 'crlf'}
function! tableops#app#table#target(line1, line2, range) abort
  let l:lnum = a:range == 0 ? line('.') : a:line1
  let l:r = tableops#domain#table#range(l:lnum)
  if empty(l:r)
    return {'ok': 0, 'code': 'not_table'}
  endif
  if a:range != 0 && (a:line2 < l:r[0] || a:line2 > l:r[1])
    return {'ok': 0, 'code': 'range'}
  endif
  let l:lines = getline(l:r[0], l:r[1])
  let l:p = tableops#domain#table#parse(l:lines)
  if !l:p.ok
    return l:p
  endif
  let l:cur = line('.')
  let l:idx = l:cur >= l:r[0] && l:cur <= l:r[1]
        \ ? tableops#domain#table#cell_index(getline(l:cur), col('.')) : -1
  return {'ok': 1, 'start': l:r[0], 'end': l:r[1], 'lines': l:lines,
        \ 'table': l:p.table, 'cursor_idx': l:idx}
endfunction

" The lines of {table} (tableops#domain#table#render()), only when they
" read back as a table of the same shape: readable, with a header when
" {table} has one and none when it has none, and as many rows. A change of
" the cells can turn a row of '-' cells into the second line (it would
" become a separator row) or the first (the table could not be read).
" Only those two lines are read again: render() writes one line per row,
" a separator row only after a header, and every | that it writes after a
" blank, so the other lines and the number of cells read back as written.
"   {'ok': 1, 'lines'} or {'ok': 0, 'code': 'ambiguous'}
function! tableops#app#table#render(table) abort
  let l:lines = tableops#domain#table#render(a:table)
  if empty(l:lines)
        \ || tableops#domain#table#is_separator(tableops#domain#table#split(l:lines[0]))
        \ || (len(l:lines) >= 2
        \     && tableops#domain#table#is_separator(tableops#domain#table#split(l:lines[1])))
        \    != !empty(a:table.header)
    return {'ok': 0, 'code': 'ambiguous'}
  endif
  return {'ok': 1, 'lines': l:lines}
endfunction

" Line number of the separator row of a table at {start}, or 0.
function! tableops#app#table#separator_lnum(start, table) abort
  return empty(a:table.header) ? 0 : a:start + 1
endfunction

" Write {new} over {old} (both from line {start}): only the lines that
" differ, so that an unchanged table makes no undo entry (F12).
"   {'ok': 1, 'changed': 0/1} or {'ok': 0, 'code': 'not_modifiable' |
"   'vim_error', 'error'}
function! tableops#app#table#write(start, old, new) abort
  if !&modifiable
    return {'ok': 0, 'code': 'not_modifiable'}
  endif
  let l:changed = 0
  try
    let l:i = 0
    for l:line in a:new
      if l:line !=# get(a:old, l:i, '')
        call setline(a:start + l:i, l:line)
        let l:changed = 1
      endif
      let l:i += 1
    endfor
  catch
    return {'ok': 0, 'code': 'vim_error', 'error': v:exception, 'changed': l:changed}
  endtry
  return {'ok': 1, 'changed': l:changed}
endfunction

" Byte column of the first non-blank of cell {idx} of {line} (the last cell
" when there are fewer). A blank cell: one blank after its |, or its start
" when it has no blank. An empty cell (||): its start, which is its
" closing | (cell_index() gives that | to the empty cell).
function! tableops#app#table#cell_start(line, idx) abort
  let l:spans = tableops#domain#table#spans(a:line)
  let l:s = l:spans[min([a:idx, len(l:spans) - 1])]
  let l:m = match(strpart(a:line, 0, l:s.end), '\m[^ \t]', l:s.start - 1)
  if l:m >= 0
    return l:m + 1
  endif
  return l:s.pipe + 2 <= l:s.end ? l:s.pipe + 2 : l:s.start
endfunction

" Put the cursor on cell {idx} of line {lnum}.
function! tableops#app#table#place(lnum, idx) abort
  call cursor(a:lnum, tableops#app#table#cell_start(getline(a:lnum), a:idx))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
