" Formatting tables: render and write back the lines that differ.

let s:save_cpo = &cpoptions
set cpoptions&vim

" The new cursor column on {new} (the formatted {old}) for the cursor at
" byte {col} of {old}. Content: the same character offset from the start of
" the cell's content (clamped to the content). A |: the same | of the new
" line. The separator row or a blank cell: the start of the cell.
function! s:cursor_col(old, new, col, is_sep) abort
  let l:spans = tableops#domain#table#spans(a:old)
  let l:idx = tableops#domain#table#cell_index(a:old, a:col)
  let l:nspans = tableops#domain#table#spans(a:new)
  let l:ns = l:nspans[min([l:idx, len(l:nspans) - 1])]
  let l:s = l:spans[l:idx]
  if a:is_sep
    return tableops#app#table#cell_start(a:new, l:idx)
  elseif a:col <= l:s.pipe
    return l:ns.pipe
  elseif l:s.end < l:s.start
    " an empty cell (||): the cursor is on its closing |
    return tableops#app#table#cell_start(a:new, l:idx)
  elseif l:s.close > 0 && a:col >= l:s.close
    return l:ns.close > 0 ? l:ns.close : l:ns.end
  endif
  let l:content = trim(l:s.text, " \t")
  if l:content ==# ''
    return tableops#app#table#cell_start(a:new, l:idx)
  endif
  let l:first = match(a:old, '\m[^ \t]', l:s.start - 1) + 1
  let l:off = a:col <= l:first ? 0 : strchars(strpart(a:old, l:first - 1, a:col - l:first))
  let l:off = min([l:off, strchars(l:content) - 1])
  return tableops#app#table#cell_start(a:new, l:idx) + strlen(strcharpart(l:content, 0, l:off))
endfunction

" [start, end] of every table with a line in {line1} .. {line2}.
function! s:tables_in(line1, line2) abort
  let l:found = []
  let l:lnum = a:line1
  while l:lnum <= a:line2
    let l:r = tableops#domain#table#range(l:lnum)
    if empty(l:r)
      let l:lnum += 1
    else
      call add(l:found, l:r)
      let l:lnum = l:r[1] + 1
    endif
  endwhile
  return l:found
endfunction

" Format the table of the cursor ({range} 0) or every table that has a line
" in {line1} .. {line2}. All tables are rendered before anything is
" written: a malformed (or ambiguous) one changes nothing.
"   {'ok', 'code', 'changed'}; code 'not_table' with 'in_range' 1 when a
"   range holds no table.
function! tableops#app#format#format(line1, line2, range) abort
  if a:range == 0
    let l:r = tableops#domain#table#range(line('.'))
    if empty(l:r)
      return {'ok': 0, 'code': 'not_table', 'in_range': 0}
    endif
    let l:ranges = [l:r]
  else
    let l:ranges = s:tables_in(a:line1, a:line2)
    if empty(l:ranges)
      return {'ok': 0, 'code': 'not_table', 'in_range': 1}
    endif
  endif
  let l:jobs = []
  for l:r in l:ranges
    let l:lines = getline(l:r[0], l:r[1])
    let l:p = tableops#domain#table#parse(l:lines)
    if !l:p.ok
      return l:p
    endif
    let l:new = tableops#app#table#render(l:p.table)
    if !l:new.ok
      return l:new
    endif
    call add(l:jobs, {'start': l:r[0], 'end': l:r[1], 'old': l:lines,
          \ 'new': l:new.lines,
          \ 'sep': tableops#app#table#separator_lnum(l:r[0], l:p.table)})
  endfor
  if !&modifiable
    return {'ok': 0, 'code': 'not_modifiable'}
  endif
  let l:lnum = line('.')
  let l:col = col('.')
  let l:changed = 0
  for l:job in l:jobs
    let l:w = tableops#app#table#write(l:job.start, l:job.old, l:job.new)
    if !l:w.ok
      " vim_error: changed is 1 when a line was written already
      let l:w.changed = l:changed || get(l:w, 'changed', 0)
      return l:w
    endif
    let l:changed = l:changed || l:w.changed
    if l:lnum >= l:job.start && l:lnum <= l:job.end
      let l:i = l:lnum - l:job.start
      call cursor(l:lnum, s:cursor_col(l:job.old[l:i], l:job.new[l:i], l:col, l:lnum == l:job.sep))
    endif
  endfor
  return {'ok': 1, 'code': '', 'changed': l:changed}
endfunction

" Format the table of line {lnum}. Silent: outside a table, a malformed
" or ambiguous table or a buffer that cannot change is no change.
function! tableops#app#format#format_at(lnum) abort
  if empty(tableops#domain#table#range(a:lnum))
    return {'ok': 1, 'code': '', 'changed': 0}
  endif
  let l:r = tableops#app#format#format(a:lnum, a:lnum, 1)
  if !l:r.ok && index(['malformed', 'crlf', 'ambiguous', 'not_modifiable'], l:r.code) >= 0
    return {'ok': 1, 'code': '', 'changed': 0}
  endif
  return l:r
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
