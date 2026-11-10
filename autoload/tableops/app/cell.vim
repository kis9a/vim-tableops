" Cell motions and text objects. They read lines only (callable under
" textlock) and never change the buffer. The rows are the lines of the
" table except its separator row.

let s:save_cpo = &cpoptions
set cpoptions&vim

" [start, end, separator lnum or 0] of the table of line {lnum}, or [].
" The separator row is the second line when it is one and the first is not
" (as parse() decides).
function! s:table(lnum) abort
  let l:r = tableops#domain#table#range(a:lnum)
  if empty(l:r)
    return []
  endif
  let l:sep = 0
  if l:r[1] > l:r[0]
        \ && tableops#domain#table#is_separator(tableops#domain#table#split(getline(l:r[0] + 1)))
        \ && !tableops#domain#table#is_separator(tableops#domain#table#split(getline(l:r[0])))
    let l:sep = l:r[0] + 1
  endif
  return [l:r[0], l:r[1], l:sep]
endfunction

" The next row after {lnum} ({step} 1) or before it ({step} -1), or 0.
function! s:next_row(t, lnum, step) abort
  let l:l = a:lnum + a:step
  if l:l == a:t[2]
    let l:l += a:step
  endif
  return l:l >= a:t[0] && l:l <= a:t[1] ? l:l : 0
endfunction

function! s:ncells(lnum) abort
  return len(tableops#domain#table#spans(getline(a:lnum)))
endfunction

" One step from cell {idx} of line {lnum} to [lnum, idx], or []. {want}
" is the cell index that up and down keep across short rows.
function! s:step(t, lnum, idx, want, dir, mode) abort
  if a:dir ==# 'right'
    if a:idx < s:ncells(a:lnum) - 1
      return [a:lnum, a:idx + 1]
    endif
    let l:l = a:mode ==# 'o' ? 0 : s:next_row(a:t, a:lnum, 1)
    return l:l ? [l:l, 0] : []
  elseif a:dir ==# 'left'
    if a:idx > 0
      return [a:lnum, min([a:idx, s:ncells(a:lnum)]) - 1]
    endif
    let l:l = a:mode ==# 'o' ? 0 : s:next_row(a:t, a:lnum, -1)
    return l:l ? [l:l, s:ncells(l:l) - 1] : []
  endif
  let l:l = s:next_row(a:t, a:lnum, a:dir ==# 'down' ? 1 : -1)
  return l:l ? [l:l, min([a:want, s:ncells(l:l) - 1])] : []
endfunction

" Where {count} steps in direction {dir} ('left', 'right', 'up', 'down')
" lead from the cursor: [lnum, col], or [] when not one step is possible
" or the cursor is not in a table. {mode} 'n', 'x' or 'o': in 'o' left and
" right do not leave the line (D15), nothing starts on the separator row
" (as the text objects), and up and down have no target when the
" separator row would be in their (linewise) range.
function! tableops#app#cell#target(dir, count, mode) abort
  let l:lnum = line('.')
  let l:t = s:table(l:lnum)
  if empty(l:t) || a:mode ==# 'o' && l:lnum == l:t[2]
    return []
  endif
  let l:idx = tableops#domain#table#cell_index(getline(l:lnum), col('.'))
  let l:want = l:idx
  let l:pos = []
  for l:_ in range(max([a:count, 1]))
    let l:next = s:step(l:t, l:lnum, l:idx, l:want, a:dir, a:mode)
    if empty(l:next)
      break
    endif
    let [l:lnum, l:idx] = l:next
    let l:pos = l:next
  endfor
  if empty(l:pos)
    return []
  endif
  " o mode: a linewise range never holds the separator row (d}| on the
  " header would delete it)
  if a:mode ==# 'o' && l:t[2] > 0 && (a:dir ==# 'up' || a:dir ==# 'down')
        \ && l:t[2] >= min([line('.'), l:lnum]) && l:t[2] <= max([line('.'), l:lnum])
    return []
  endif
  return [l:lnum, tableops#app#table#cell_start(getline(l:lnum), l:idx)]
endfunction

" Move the cursor as target() says, with the count of now (o mode runs this
" when the operator runs, so . finds the target again).
function! tableops#app#cell#go(dir, mode) abort
  let l:pos = tableops#app#cell#target(a:dir, v:count1, a:mode)
  if !empty(l:pos)
    call cursor(l:pos[0], l:pos[1])
  endif
endfunction

" The cursor cell as [lnum, from, to] (bytes, to is the first byte of the
" last character), or []. {inner}: the content without the blanks around
" it (a blank cell: all of it; || : []). Else: from after the | through the
" closing | (the end of the line when there is none).
function! tableops#app#cell#select_range(inner) abort
  let l:lnum = line('.')
  let l:t = s:table(l:lnum)
  if empty(l:t) || l:lnum == l:t[2]
    return []
  endif
  let l:line = getline(l:lnum)
  let l:s = tableops#domain#table#spans(l:line)[tableops#domain#table#cell_index(l:line, col('.'))]
  if a:inner
    if l:s.end < l:s.start
      return []
    endif
    let l:text = strpart(l:line, 0, l:s.end)
    let l:from = match(l:text, '\m[^ \t]', l:s.start - 1)
    if l:from < 0
      return [l:lnum, l:s.start, l:s.end]
    endif
    let l:to = match(l:text, '\m[^ \t][ \t]*$', l:s.start - 1)
    return [l:lnum, l:from + 1, l:to + 1]
  endif
  if l:s.close > 0
    return [l:lnum, l:s.start, l:s.close]
  endif
  if l:s.end < l:s.start
    return []
  endif
  return [l:lnum, l:s.start, l:s.end - strlen(matchstr(strpart(l:line, 0, l:s.end), '\m.$')) + 1]
endfunction

" Select the cursor cell in Visual mode (from :<C-u> in x and o mode). With
" 'selection' exclusive the end is one character further (past the end of
" the line is fine for cursor()).
function! tableops#app#cell#select(inner) abort
  let l:r = tableops#app#cell#select_range(a:inner)
  if empty(l:r)
    return
  endif
  let [l:lnum, l:from, l:to] = l:r
  let l:to_col = l:to
  if &selection ==# 'exclusive'
    let l:to_col += max([strlen(matchstr(getline(l:lnum), '\m.', l:to - 1)), 1])
  endif
  call cursor(l:lnum, l:from)
  normal! v
  call cursor(l:lnum, l:to_col)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
