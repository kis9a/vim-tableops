scriptencoding utf-8

let s:suite = themis#suite('command_format')
let s:assert = themis#helper('assert')

let s:T = [
      \ 'intro',
      \ '|name|年齢|',
      \ '|:-|-:|',
      \ '| foo | 12 |',
      \ '|bar|',
      \ 'outro']

let s:F = [
      \ 'intro',
      \ '| name | 年齢 |',
      \ '|:-----|-----:|',
      \ '| foo  |   12 |',
      \ '| bar  |      |',
      \ 'outro']

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  messages clear
endfunction

function! s:suite.after_each() abort
  setlocal modifiable
endfunction

function! s:unchanged(lines, msg) abort
  call s:assert.equals(TableopsTestLines(), a:lines)
  call s:assert.equals(TableopsTestMessage(), '[tableops] ' . a:msg)
endfunction

function! s:suite.format_the_cursor_table() abort
  call cursor(4, 1)
  TableopsFormat
  call s:assert.equals(TableopsTestLines(), s:F)
  silent undo
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

function! s:suite.format_with_the_mapping() abort
  call cursor(2, 1)
  execute "normal \<Plug>(tableops-format)"
  call s:assert.equals(TableopsTestLines(), s:F)
endfunction

function! s:suite.format_twice_is_no_change() abort
  call cursor(3, 1)
  TableopsFormat
  let l:tick = changenr()
  TableopsFormat
  call s:assert.equals(TableopsTestLines(), s:F)
  call s:assert.equals(changenr(), l:tick)
endfunction

function! s:suite.format_outside_a_table() abort
  call cursor(1, 1)
  TableopsFormat
  call s:unchanged(s:T, 'not in a table')
  1TableopsFormat
  call s:unchanged(s:T, 'no table in range')
  execute "normal \<Plug>(tableops-format)"
  call s:unchanged(s:T, 'not in a table')
endfunction

function! s:suite.format_a_range_formats_every_table_in_it() abort
  let l:two = ['|a|b|', '|-|-|', '|1|2|', 'text', '| x |y|']
  let l:want = ['| a | b |', '|---|---|', '| 1 | 2 |', 'text', '| x | y |']
  call TableopsTestBuffer(l:two)
  call cursor(4, 2)
  %TableopsFormat
  call s:assert.equals(TableopsTestLines(), l:want)
  call s:assert.equals([line('.'), col('.')], [4, 2])
  silent undo
  call s:assert.equals(TableopsTestLines(), l:two)
  " a part of the first table: all of it, and not the other one
  3TableopsFormat
  call s:assert.equals(TableopsTestLines(), l:want[0 : 3] + l:two[4 :])
  silent undo
  " a range that ends in the second table
  3,5TableopsFormat
  call s:assert.equals(TableopsTestLines(), l:want)
endfunction

function! s:suite.format_range_with_a_bad_table_changes_nothing() abort
  let l:two = ['|a|b|', '|-|-|', 'text', '|-|-|', '|1|2|']
  call TableopsTestBuffer(l:two)
  let l:tick = changenr()
  %TableopsFormat
  call s:unchanged(l:two, 'the table starts with a separator row')
  call s:assert.equals(changenr(), l:tick)
  let l:crlf = ['|a|b|', 'text', "|1|2|\r"]
  call TableopsTestBuffer(l:crlf)
  %TableopsFormat
  call s:unchanged(l:crlf, 'CR line endings: try :e ++ff=dos')
endfunction

function! s:suite.format_already_formatted_makes_no_change() abort
  call TableopsTestBuffer(s:F)
  call cursor(4, 1)
  let l:tick = changenr()
  TableopsFormat
  %TableopsFormat
  call s:assert.equals(TableopsTestLines(), s:F)
  call s:assert.equals(changenr(), l:tick)
endfunction

function! s:suite.format_nomodifiable() abort
  call cursor(4, 1)
  setlocal nomodifiable
  TableopsFormat
  call s:unchanged(s:T, '''modifiable'' is off (E21)')
endfunction

function! s:suite.format_keeps_the_cursor_in_its_cell() abort
  " the second o of foo
  call TableopsTestCursor(4, 'o', 2)
  TableopsFormat
  call s:assert.equals([line('.'), col('.'), TableopsTestChar()], [4, 5, 'o'])
  " the 2 of 12, in a right-aligned column
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  TableopsFormat
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '2'])
  " a full-width character
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(2, '齢')
  TableopsFormat
  call s:assert.equals([line('.'), TableopsTestChar()], [2, '齢'])
  " a blank after the content: the last character of the content
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, 'o ')
  call cursor(4, col('.') + 1)
  TableopsFormat
  call s:assert.equals([line('.'), col('.')], [4, 5])
  " a |: the same | of the new line
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '|', 2)
  TableopsFormat
  call s:assert.equals([line('.'), col('.'), TableopsTestChar()], [4, 8, '|'])
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '|', 3)
  TableopsFormat
  call s:assert.equals([line('.'), col('.'), TableopsTestChar()], [4, 15, '|'])
  " the separator row: the start of the cell
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(3, '-:')
  TableopsFormat
  call s:assert.equals([line('.'), col('.')], [3, 9])
  " the closing | of a short row: the same | (now between two cells)
  call TableopsTestBuffer(s:T)
  call cursor(5, 5)
  TableopsFormat
  call s:assert.equals([line('.'), col('.'), TableopsTestChar()], [5, 8, '|'])
endfunction

function! s:suite.format_at() abort
  " outside a table: nothing, silently
  let l:r = tableops#format_at(1)
  call s:assert.equals([l:r.ok, l:r.changed], [1, 0])
  call s:assert.equals(TableopsTestLines(), s:T)
  call s:assert.equals(TableopsTestMessage() =~# 'tableops', 0)
  " inside: the table of that line, wherever the cursor is
  call cursor(6, 1)
  let l:r = tableops#format_at(3)
  call s:assert.equals([l:r.ok, l:r.changed], [1, 1])
  call s:assert.equals(TableopsTestLines(), s:F)
  call s:assert.equals([line('.'), col('.')], [6, 1])
endfunction

function! s:suite.format_at_is_silent_on_errors() abort
  setlocal nomodifiable
  call s:assert.equals(tableops#format_at(3).changed, 0)
  setlocal modifiable
  let l:bad = ['|-|-|', '|1|2|']
  call TableopsTestBuffer(l:bad)
  call s:assert.equals(tableops#format_at(1).changed, 0)
  call TableopsTestBuffer(["|a|\r"])
  call s:assert.equals(tableops#format_at(1).changed, 0)
  call s:assert.equals(TableopsTestLines(), ["|a|\r"])
  call s:assert.equals(TableopsTestMessage() =~# 'tableops', 0)
endfunction

function! s:suite.render_refuses_lines_that_read_back_otherwise() abort
  let l:t = {'indent': '', 'header': [], 'align': [''], 'rows': [['b'], ['-']]}
  call s:assert.equals(tableops#app#table#render(l:t), {'ok': 0, 'code': 'ambiguous'})
  let l:t.rows = [['-'], ['b']]
  call s:assert.equals(tableops#app#table#render(l:t), {'ok': 0, 'code': 'ambiguous'})
  let l:t.rows = [['b'], ['c'], ['-']]
  call s:assert.equals(tableops#app#table#render(l:t),
        \ {'ok': 1, 'lines': ['| b |', '| c |', '| - |']})
  let l:t = {'indent': '', 'header': ['-'], 'align': [''], 'rows': [['b']]}
  call s:assert.equals(tableops#app#table#render(l:t), {'ok': 0, 'code': 'ambiguous'})
endfunction

function! s:suite.cursor_in_an_empty_cell_stays_in_it() abort
  call TableopsTestBuffer(['|a||b|'])
  " the cursor of the empty cell is its closing |
  call cursor(1, 4)
  TableopsFormat
  call s:assert.equals(getline(1), '| a |   | b |')
  call s:assert.equals(tableops#domain#table#cell_index(getline(1), col('.')), 1)
endfunction

" ---- widths do not depend on the window (E1) ----------------------------------

function! s:suite.widths_ignore_showbreak_and_the_window() abort
  let l:long = trim(repeat('word ', 40))
  let l:t = ['| a | b |', '|---|---|', '| ' . l:long . ' | x |', '| short 全角 | y |']
  call TableopsTestBuffer(l:t)
  TableopsFormat
  let l:want = TableopsTestLines()
  call s:assert.equals(map(copy(l:want), 'strwidth(v:val)'), [207, 207, 207, 207])
  let l:save = [&showbreak, &linebreak, &number, &list]
  try
    set showbreak=>>\  linebreak number list
    call TableopsTestBuffer(l:t)
    TableopsFormat
    call s:assert.equals(TableopsTestLines(), l:want, 'showbreak')
    " a narrow window, a wide character at its edge
    vsplit
    vertical resize 21
    call TableopsTestBuffer(l:t)
    TableopsFormat
    call s:assert.equals(TableopsTestLines(), l:want, 'narrow window')
  finally
    let [&showbreak, &linebreak, &number, &list] = l:save
    only!
  endtry
endfunction

" ---- the structure check agrees with a full parse (E4) ------------------------

function! s:suite.render_check_agrees_with_a_full_parse() abort
  let l:seed = 4242
  let l:words = ['-', '--', ':-', '-:', ':-:', '', 'a', '\-', '|']
  for l:_ in range(1500)
    let l:seed = (l:seed * 1103515245 + 12345) % 2147483648
    let l:r = l:seed / 65536
    let l:n = 1 + l:r % 3
    let l:rows = 1 + (l:r / 3) % 4
    let l:cells = []
    for l:i in range((l:rows + 1) * l:n)
      let l:seed = (l:seed * 1103515245 + 12345) % 2147483648
      call add(l:cells, l:words[(l:seed / 65536) % len(l:words)])
    endfor
    let l:t = {'indent': '', 'align': repeat([''], l:n),
          \ 'header': l:r % 2 ? l:cells[0 : l:n - 1] : [],
          \ 'rows': map(range(l:rows), 'l:cells[(v:val + 1) * l:n : (v:val + 2) * l:n - 1]')}
    let l:lines = tableops#domain#table#render(l:t)
    let l:p = tableops#domain#table#parse(l:lines)
    let l:same = l:p.ok && empty(l:p.table.header) == empty(l:t.header)
          \ && len(l:p.table.rows) == len(l:t.rows)
    let l:got = tableops#app#table#render(l:t)
    call s:assert.equals(l:got.ok, l:same, string(l:t))
  endfor
endfunction
