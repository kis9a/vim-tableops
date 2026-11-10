" Pure column transformations of a parsed table, the column search pattern
" and argument parsing. Every function returns a copy; inputs are never
" changed. Calls nothing outside this file.

let s:save_cpo = &cpoptions
set cpoptions&vim

" {table} without the columns {idxs} (0-based; duplicates are ignored).
function! tableops#domain#column#delete(table, idxs) abort
  let l:t = deepcopy(a:table)
  let l:idxs = reverse(uniq(sort(copy(a:idxs), 'n')))
  for l:i in l:idxs
    if !empty(l:t.header)
      call remove(l:t.header, l:i)
    endif
    call remove(l:t.align, l:i)
    for l:row in l:t.rows
      call remove(l:row, l:i)
    endfor
  endfor
  return l:t
endfunction

" {table} with an empty column at {pos} (0 .. n). Its align is ''.
function! tableops#domain#column#insert(table, pos) abort
  let l:t = deepcopy(a:table)
  if !empty(l:t.header)
    call insert(l:t.header, '', a:pos)
  endif
  call insert(l:t.align, '', a:pos)
  for l:row in l:t.rows
    call insert(l:row, '', a:pos)
  endfor
  return l:t
endfunction

" {table} with column {from} taken out and put back at {to}.
function! tableops#domain#column#move(table, from, to) abort
  let l:t = deepcopy(a:table)
  for l:list in (empty(l:t.header) ? [] : [l:t.header]) + [l:t.align] + l:t.rows
    call insert(l:list, remove(l:list, a:from), a:to)
  endfor
  return l:t
endfunction

" A string whose byte order is the order of the first number in {cell}
" (-\=\d\+\%(\.\d\+\)\=, compared exactly as a decimal): '0' without a
" number, '1...' negative, '2...' zero or positive. A negative number has
" its digits complemented and ends in ':' (above every digit), so that
" -1.5 < -1.4 < -1.
function! s:number_key(cell) abort
  let l:m = matchlist(a:cell, '\m\(-\=\)\(\d\+\)\%(\.\(\d\+\)\)\=')
  if empty(l:m)
    return '0'
  endif
  let l:int = substitute(l:m[2], '\m^0\+', '', '')
  let l:frac = substitute(l:m[3], '\m0\+$', '', '')
  if l:m[1] ==# '' || l:int . l:frac ==# ''
    return '2' . printf('%05d', len(l:int)) . l:int . l:frac
  endif
  return '1' . printf('%05d', 99999 - len(l:int))
        \ . tr(l:int . l:frac, '0123456789', '9876543210') . ':'
endfunction

" {table} with its rows (not the header) sorted by column {idx}, stably.
" {opts}: {'numeric', 'icase', 'reverse'} (missing keys are false).
" numeric: by the first -\=\d\+\%(\.\d\+\)\= of the cell; cells without a
" number come first (as :sort n), last when reversed. icase: compare
" tolower(); ignored with numeric. Otherwise byte order. Equal keys keep
" their order, also when reversed.
"
" The keys are computed first and sorted by the built-in byte order: each
" is key . "\x01\x01" . row index (reversed for reverse), with \x01 in the
" key written \x01\x02, so a key that is a prefix of another comes first.
function! tableops#domain#column#sort(table, idx, opts) abort
  let l:t = deepcopy(a:table)
  let l:numeric = get(a:opts, 'numeric', 0)
  let l:icase = get(a:opts, 'icase', 0)
  let l:reverse = get(a:opts, 'reverse', 0)
  let l:keys = []
  let l:i = 0
  for l:row in l:t.rows
    if l:numeric
      let l:key = s:number_key(l:row[a:idx])
    else
      let l:key = l:icase ? tolower(l:row[a:idx]) : l:row[a:idx]
      if stridx(l:key, "\x01") >= 0
        let l:key = substitute(l:key, "\x01", "\x01\x02", 'g')
      endif
    endif
    call add(l:keys, l:key . "\x01\x01" . printf('%08d', l:reverse ? 99999999 - l:i : l:i))
    let l:i += 1
  endfor
  call sort(l:keys)
  if l:reverse
    call reverse(l:keys)
    let l:t.rows = map(l:keys, 'l:t.rows[99999999 - str2nr(v:val[-8 :], 10)]')
  else
    let l:t.rows = map(l:keys, 'l:t.rows[str2nr(v:val[-8 :], 10)]')
  endif
  return l:t
endfunction

" One cell of the search pattern: \| , a \ not before | , or not | nor \.
let s:cell = '%(\\\||\\%(\|)@!|[^|\\])'

" A very magic pattern for the | and the text of column {idx} (0-based) on
" each row. It does not match the closing | of a row with only idx cells.
function! tableops#domain#column#pattern(idx) abort
  return '\v^\s*%(\|' . s:cell . '*){' . a:idx . '}\zs\|%(\s*$)@!' . s:cell . '*'
endfunction

function! s:bad(code, arg) abort
  return {'ok': 0, 'code': a:code, 'arg': a:arg}
endfunction

" Column numbers in {args} (blank separated, 1 .. {n}) as 0-based indexes,
" without duplicates, ascending: {'ok': 1, 'idxs': [...]}. On a bad word:
" {'ok': 0, 'code': 'bad_column', 'arg': word}.
function! tableops#domain#column#parse_columns(args, n) abort
  let l:seen = {}
  for l:w in split(a:args)
    if l:w !~# '\m^\d\+$'
      return s:bad('bad_column', l:w)
    endif
    let l:nr = str2nr(l:w, 10)
    if l:nr < 1 || l:nr > a:n
      return s:bad('bad_column', l:w)
    endif
    let l:seen[l:nr - 1] = 1
  endfor
  return {'ok': 1, 'idxs': sort(map(keys(l:seen), 'str2nr(v:val)'), 'n')}
endfunction

" [N] [n][i] of :TableopsSortColumn: {'ok': 1, 'idx': 0-based or -1,
" 'numeric', 'icase'}. A column number out of 1 .. {n}: 'bad_column'; a
" second number or another word: 'bad_args'.
function! tableops#domain#column#parse_sort_args(args, n) abort
  let l:r = {'ok': 1, 'idx': -1, 'numeric': 0, 'icase': 0}
  for l:w in split(a:args)
    if l:w =~# '\m^\d\+$'
      if l:r.idx >= 0
        return s:bad('bad_args', l:w)
      endif
      let l:nr = str2nr(l:w, 10)
      if l:nr < 1 || l:nr > a:n
        return s:bad('bad_column', l:w)
      endif
      let l:r.idx = l:nr - 1
    elseif l:w =~# '\m^[ni]\+$'
      let l:r.numeric = l:r.numeric || l:w =~# 'n'
      let l:r.icase = l:r.icase || l:w =~# 'i'
    else
      return s:bad('bad_args', l:w)
    endif
  endfor
  return l:r
endfunction

" The signed distance in {arg} ('2', '+2', '-1'), or v:null.
function! tableops#domain#column#parse_delta(arg) abort
  let l:s = trim(a:arg)
  if l:s !~# '\m^[+-]\=\d\+$'
    return v:null
  endif
  let l:nr = str2nr(substitute(l:s, '\m^+', '', ''), 10)
  return l:nr
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
