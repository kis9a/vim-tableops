" Pure functions on Markdown table lines. range() is the only one that reads
" the buffer (getline only); nothing here writes or calls outside this file.
"
" Grammar (owned by s:pieces() alone, under spans() and split()): a |
" separates cells unless it is
" written \| , which is always a character of the cell (so \\| is \ and \|).
" Any other \ is an ordinary character. The trailing | is optional.
" So a | separates cells exactly when the byte before it is not \.

let s:save_cpo = &cpoptions
set cpoptions&vim

function! tableops#domain#table#is_row(line) abort
  return a:line =~# '\m^\s*|'
endfunction

" [start, end] of the table that holds line {lnum}, or [].
function! tableops#domain#table#range(lnum) abort
  if !tableops#domain#table#is_row(getline(a:lnum))
    return []
  endif
  let l:start = a:lnum
  while l:start > 1 && tableops#domain#table#is_row(getline(l:start - 1))
    let l:start -= 1
  endwhile
  let l:end = a:lnum
  let l:last = line('$')
  while l:end < l:last && tableops#domain#table#is_row(getline(l:end + 1))
    let l:end += 1
  endwhile
  return [l:start, l:end]
endfunction

" The grammar, in one place: [p, pieces, closed] for {line}.
"   p       byte offset (0-based) of the first |, or -1
"   pieces  the raw text of each cell (at least one)
"   closed  1 when a | closes the last cell
" A last piece of blanks after a | is no cell: that | closes the previous
" cell. A line without a cell ('|', '  |') has one empty cell; a line
" without | is one cell.
function! s:pieces(line) abort
  if stridx(a:line, "\x01") < 0
    " \| becomes two bytes that are no |: the lengths do not change
    let l:s = substitute(a:line, '\m\\|', "\x01\x01", 'g')
    let l:p = stridx(l:s, '|')
    if l:p < 0
      return [-1, [a:line], 0]
    endif
    let l:pieces = split(strpart(l:s, l:p + 1), '|', 1)
    if l:s !=# a:line
      call map(l:pieces, 'stridx(v:val, "\x01") < 0 ? v:val : substitute(v:val, "\x01\x01", "\\\\|", "g")')
    endif
  else
    " the line has \x01 already: find each | that has no \ before it
    " (stridx only, no regexp: any line length is linear)
    let l:bars = []
    let l:i = stridx(a:line, '|')
    while l:i >= 0
      if l:i == 0 || a:line[l:i - 1] !=# '\'
        call add(l:bars, l:i)
      endif
      let l:i = stridx(a:line, '|', l:i + 1)
    endwhile
    if empty(l:bars)
      return [-1, [a:line], 0]
    endif
    let l:p = l:bars[0]
    call add(l:bars, strlen(a:line))
    let l:pieces = map(range(len(l:bars) - 1),
          \ 'strpart(a:line, l:bars[v:val] + 1, l:bars[v:val + 1] - l:bars[v:val] - 1)')
  endif
  if l:pieces[-1] =~# '\m^[ \t]*$'
    call remove(l:pieces, -1)
    if empty(l:pieces)
      return [l:p, [''], 0]
    endif
    return [l:p, l:pieces, 1]
  endif
  return [l:p, l:pieces, 0]
endfunction

" The cells of {line}, at least one:
"   {'pipe': |, 'start': pipe + 1, 'end': last byte, 'close': next | or 0,
"    'text': raw text between them}  (byte positions, 1-based)
" An empty cell (||) has end = start - 1. A line without | gives one cell
" that is the whole line, with pipe 0.
function! tableops#domain#table#spans(line) abort
  let [l:p, l:pieces, l:closed] = s:pieces(a:line)
  if l:p < 0
    return [{'pipe': 0, 'start': 1, 'end': strlen(a:line), 'close': 0, 'text': a:line}]
  endif
  let l:spans = []
  let l:pipe = l:p + 1
  let l:last = len(l:pieces) - 1
  let l:i = 0
  for l:text in l:pieces
    let l:end = l:pipe + strlen(l:text)
    call add(l:spans, {'pipe': l:pipe, 'start': l:pipe + 1, 'end': l:end,
          \ 'close': l:i < l:last || l:closed ? l:end + 1 : 0, 'text': l:text})
    let l:pipe = l:end + 1
    let l:i += 1
  endfor
  return l:spans
endfunction

" The cell texts of {line} without the blanks around them.
function! tableops#domain#table#split(line) abort
  return map(s:pieces(a:line)[1], 'trim(v:val, " \t")')
endfunction

" Index (0-based) of the cell at byte {col} (1-based). Before the first |
" it is 0; a | belongs to the cell on its right, except the | right after
" an empty cell (||), which belongs to that cell: the empty cell has no
" byte of its own and the cursor stands on its closing |. The closing |
" and what is after it belong to the last cell.
function! tableops#domain#table#cell_index(line, col) abort
  let l:spans = tableops#domain#table#spans(a:line)
  let l:i = len(l:spans) - 1
  while l:i > 0 && a:col < l:spans[l:i].pipe
    let l:i -= 1
  endwhile
  return s:owner(l:spans, l:i, a:col == l:spans[l:i].pipe)
endfunction

" Cell {i}, or the empty cell left of it when {on_pipe} (on the | of {i}).
function! s:owner(spans, i, on_pipe) abort
  return a:i > 0 && a:on_pipe && a:spans[a:i - 1].end < a:spans[a:i - 1].start
        \ ? a:i - 1 : a:i
endfunction

" Index (0-based) of the cell at screen column {vcol} (1-based), as
" cell_index() but by display width (full-width characters are 2). With
" {end} 1 (the end of a selection), a | between two cells belongs to the
" cell on its left: the selection stops at that cell's closing |.
function! tableops#domain#table#vcell_index(line, vcol, ...) abort
  let l:spans = tableops#domain#table#spans(a:line)
  let l:i = len(l:spans) - 1
  let l:vstart = 0
  while l:i > 0
    let l:vstart = strdisplaywidth(strpart(a:line, 0, l:spans[l:i].pipe - 1)) + 1
    if a:vcol >= l:vstart
      break
    endif
    let l:i -= 1
  endwhile
  let l:on_pipe = l:i > 0 && a:vcol == l:vstart
  if l:on_pipe && get(a:000, 0, 0)
    return l:i - 1
  endif
  return s:owner(l:spans, l:i, l:on_pipe)
endfunction

" True when the trimmed {cells} are a separator row: each is empty or
" :\=-\+:\= and at least one has a -.
function! tableops#domain#table#is_separator(cells) abort
  let l:dash = 0
  for l:c in a:cells
    if l:c ==# ''
      continue
    endif
    if l:c !~# '\m^:\=-\+:\=$'
      return 0
    endif
    let l:dash = 1
  endfor
  return l:dash
endfunction

" '' / 'l' / 'c' / 'r' of a separator cell.
function! tableops#domain#table#align_of(cell) abort
  if a:cell =~# '\m^:-\+:$'
    return 'c'
  elseif a:cell =~# '\m^:-\+$'
    return 'l'
  elseif a:cell =~# '\m^-\+:$'
    return 'r'
  endif
  return ''
endfunction

function! s:fill(cells, n) abort
  return len(a:cells) < a:n ? a:cells + repeat([''], a:n - len(a:cells)) : a:cells
endfunction

" {'ok': 1, 'table': {indent, header, align, rows}} or
" {'ok': 0, 'code': 'crlf' | 'malformed'}.
function! tableops#domain#table#parse(lines) abort
  if empty(a:lines)
    return {'ok': 0, 'code': 'malformed'}
  endif
  for l:line in a:lines
    if l:line =~# '\r$'
      return {'ok': 0, 'code': 'crlf'}
    endif
  endfor
  let l:cells = map(copy(a:lines), 'tableops#domain#table#split(v:val)')
  if tableops#domain#table#is_separator(l:cells[0])
    return {'ok': 0, 'code': 'malformed'}
  endif
  let l:n = max([1] + map(copy(l:cells), 'len(v:val)'))
  let l:has_header = len(l:cells) >= 2 && tableops#domain#table#is_separator(l:cells[1])
  if l:has_header
    let l:header = s:fill(l:cells[0], l:n)
    let l:align = map(s:fill(l:cells[1], l:n), 'tableops#domain#table#align_of(v:val)')
    let l:body = l:cells[2 :]
  else
    let l:header = []
    let l:align = repeat([''], l:n)
    let l:body = l:cells
  endif
  return {'ok': 1, 'table': {
        \ 'indent': matchstr(a:lines[0], '\m^[ \t]*'),
        \ 'header': l:header,
        \ 'align': l:align,
        \ 'rows': map(l:body, 's:fill(v:val, l:n)')}}
endfunction

function! s:sep(align, width) abort
  let l:len = a:width + 2
  if a:align ==# 'l'
    return ':' . repeat('-', l:len - 1)
  elseif a:align ==# 'r'
    return repeat('-', l:len - 1) . ':'
  elseif a:align ==# 'c'
    return ':' . repeat('-', l:len - 2) . ':'
  endif
  return repeat('-', l:len)
endfunction

" The lines of {table}: columns as wide as their widest cell (at least 1),
" right-aligned columns padded on the left, the others on the right; a
" separator row only when there is a header. Widths are strwidth(): not
" strdisplaywidth(), which counts 'showbreak', 'list' and the padding of a
" wide character at the edge of the window when a line would wrap.
function! tableops#domain#table#render(table) abort
  let l:n = len(a:table.align)
  let l:has_header = !empty(a:table.header)
  let l:all = (l:has_header ? [a:table.header] : []) + a:table.rows
  " widths of every cell, then of every column
  let l:dw = map(copy(l:all), 'map(copy(v:val), "strwidth(v:val)")')
  let l:w = map(range(l:n), 'max([1] + map(copy(l:dw), "v:val[" . v:val . "]"))')
  let l:right = map(copy(a:table.align), 'v:val ==# "r"')
  let l:lines = []
  let l:i = 0
  for l:row in map(l:all, 'copy(v:val)')
    let l:d = l:dw[l:i]
    call map(l:row, 'l:right[v:key] ? repeat(" ", l:w[v:key] - l:d[v:key]) . v:val : v:val . repeat(" ", l:w[v:key] - l:d[v:key])')
    call add(l:lines, a:table.indent . '| ' . join(l:row, ' | ') . ' |')
    let l:i += 1
  endfor
  if l:has_header
    let l:seps = map(range(l:n), 's:sep(a:table.align[v:val], l:w[v:val])')
    call insert(l:lines, a:table.indent . '|' . join(l:seps, '|') . '|', 1)
  endif
  return l:lines
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
