scriptencoding utf-8

let s:suite = themis#suite('domain_table')
let s:assert = themis#helper('assert')

function! s:spans(line) abort
  return tableops#domain#table#spans(a:line)
endfunction

function! s:split(line) abort
  return tableops#domain#table#split(a:line)
endfunction

function! s:roundtrip(lines) abort
  let l:r = tableops#domain#table#parse(a:lines)
  call s:assert.true(l:r.ok)
  return tableops#domain#table#render(l:r.table)
endfunction

" The table of the requirement.
let s:example = [
      \ '| name | 年齢 | city \| area |',
      \ '|:-----|-----:|:------------:|',
      \ '| foo  |   12 | tokyo        |']

" Lines whose cells are easy to get wrong.
let s:tricky = [
      \ '| a | b |',
      \ '| a | b',
      \ '| a | b |   ',
      \ "| a | b |\t",
      \ '| a \| b | c |',
      \ '| a \\| b | c |',
      \ '| a \\\| b | c |',
      \ "| a \x01 b | c \\| d |",
      \ "| \x01\x01 | \\| |",
      \ '||',
      \ '|||',
      \ '| a || b |',
      \ '|',
      \ '  |',
      \ '|   ',
      \ "\t| a | b |",
      \ '| a\ | b\',
      \ '| a | b \',
      \ '| 年齢 | 全角 |',
      \ 'no pipe here',
      \ '',
      \ '\| a | b |',
      \ ]

" ---- is_row / range --------------------------------------------------------

function! s:suite.is_row() abort
  call s:assert.true(tableops#domain#table#is_row('| a |'))
  call s:assert.true(tableops#domain#table#is_row("  \t| a"))
  call s:assert.false(tableops#domain#table#is_row('a | b |'))
  call s:assert.false(tableops#domain#table#is_row(''))
endfunction

function! s:suite.range() abort
  call TableopsTestBuffer(['text', '| a |', '|---|', '| b |', '', '  | c |'])
  call s:assert.equals(tableops#domain#table#range(1), [])
  call s:assert.equals(tableops#domain#table#range(2), [2, 4])
  call s:assert.equals(tableops#domain#table#range(3), [2, 4])
  call s:assert.equals(tableops#domain#table#range(4), [2, 4])
  call s:assert.equals(tableops#domain#table#range(5), [])
  call s:assert.equals(tableops#domain#table#range(6), [6, 6])
endfunction

function! s:suite.range_at_buffer_edges() abort
  call TableopsTestBuffer(['| a |', '| b |'])
  call s:assert.equals(tableops#domain#table#range(1), [1, 2])
  call s:assert.equals(tableops#domain#table#range(2), [1, 2])
endfunction

" ---- spans / split ---------------------------------------------------------

function! s:suite.split_and_spans_agree() abort
  for l:line in s:tricky
    let l:spans = s:spans(l:line)
    call s:assert.equals(len(s:split(l:line)), len(l:spans), string(l:line))
    call s:assert.true(len(l:spans) >= 1, string(l:line))
  endfor
endfunction

function! s:suite.spans_text_is_between_start_and_end() abort
  for l:line in s:tricky
    for l:s in s:spans(l:line)
      call s:assert.equals(l:s.text, strpart(l:line, l:s.start - 1, l:s.end - l:s.start + 1), string(l:line))
      if l:s.pipe > 0
        call s:assert.equals(l:line[l:s.pipe - 1], '|', string(l:line))
        call s:assert.equals(l:s.start, l:s.pipe + 1)
      endif
      if l:s.close > 0
        call s:assert.equals(l:line[l:s.close - 1], '|', string(l:line))
        call s:assert.equals(l:s.end, l:s.close - 1)
      endif
    endfor
  endfor
endfunction

function! s:suite.fast_path_and_slow_path_agree() abort
  " the same lines with an \x01 added at the end of the first cell
  for l:line in s:tricky
    let l:p = stridx(l:line, '|')
    if l:p < 0 || stridx(l:line, "\x01") >= 0
      continue
    endif
    let l:with = strpart(l:line, 0, l:p + 1) . "\x01" . strpart(l:line, l:p + 1)
    let l:a = map(s:spans(l:line), '[v:val.pipe, v:val.close]')
    let l:b = map(s:spans(l:with), '[v:val.pipe, v:val.close]')
    " every position after the inserted byte moves by one
    call map(l:b, '[v:val[0] > l:p + 1 ? v:val[0] - 1 : v:val[0], v:val[1] > l:p + 1 ? v:val[1] - 1 : v:val[1]]')
    call s:assert.equals(l:b, l:a, string(l:line))
  endfor
endfunction

function! s:suite.spans_closed_row() abort
  call s:assert.equals(s:spans('| foo | b |'), [
        \ {'pipe': 1, 'start': 2, 'end': 6, 'close': 7, 'text': ' foo '},
        \ {'pipe': 7, 'start': 8, 'end': 10, 'close': 11, 'text': ' b '}])
endfunction

function! s:suite.spans_open_row() abort
  call s:assert.equals(s:spans('| a | b'), [
        \ {'pipe': 1, 'start': 2, 'end': 4, 'close': 5, 'text': ' a '},
        \ {'pipe': 5, 'start': 6, 'end': 7, 'close': 0, 'text': ' b'}])
endfunction

function! s:suite.spans_trailing_blanks() abort
  let l:s = s:spans("| a |  \t")
  call s:assert.equals(len(l:s), 1)
  call s:assert.equals(l:s[0].close, 5)
endfunction

function! s:suite.spans_empty_cell() abort
  let l:s = s:spans('| a || b |')
  call s:assert.equals(len(l:s), 3)
  call s:assert.equals([l:s[1].pipe, l:s[1].start, l:s[1].end, l:s[1].close, l:s[1].text], [5, 6, 5, 6, ''])
endfunction

function! s:suite.spans_line_without_cells() abort
  call s:assert.equals(s:spans('|'), [{'pipe': 1, 'start': 2, 'end': 1, 'close': 0, 'text': ''}])
  call s:assert.equals(s:spans('  |'), [{'pipe': 3, 'start': 4, 'end': 3, 'close': 0, 'text': ''}])
  call s:assert.equals(s:spans('||'), [{'pipe': 1, 'start': 2, 'end': 1, 'close': 2, 'text': ''}])
endfunction

function! s:suite.spans_line_without_pipe() abort
  call s:assert.equals(s:spans('abc'), [{'pipe': 0, 'start': 1, 'end': 3, 'close': 0, 'text': 'abc'}])
  call s:assert.equals(s:split(''), [''])
endfunction

function! s:suite.split_escaped_pipe() abort
  call s:assert.equals(s:split('| a \| b | c |'), ['a \| b', 'c'])
  " \\| is \ and \| : still inside the cell
  call s:assert.equals(s:split('| a \\| b | c |'), ['a \\| b', 'c'])
  call s:assert.equals(s:split('| a \\\| b | c |'), ['a \\\| b', 'c'])
  call s:assert.equals(s:split('| \| |'), ['\|'])
endfunction

function! s:suite.split_with_x01() abort
  call s:assert.equals(s:split("| a \x01 b | c \\| d |"), ["a \x01 b", 'c \| d'])
  call s:assert.equals(s:split("| \x01\x01 | \\| |"), ["\x01\x01", '\|'])
  call s:assert.equals(s:split("|\x01|"), ["\x01"])
  call s:assert.equals(s:split("|\x01||"), ["\x01", ''])
  call s:assert.equals(s:split("|\x01\\"), ["\x01\\"])
endfunction

function! s:suite.split_trailing_backslash() abort
  call s:assert.equals(s:split('| a | b \'), ['a', 'b \'])
  call s:assert.equals(s:split('| a\ | b\'), ['a\', 'b\'])
endfunction

function! s:suite.split_tab_indent_and_cells() abort
  call s:assert.equals(s:split("\t| a\t|\tb |"), ['a', 'b'])
endfunction

function! s:suite.split_open_and_closed() abort
  call s:assert.equals(s:split('| a | b'), ['a', 'b'])
  call s:assert.equals(s:split('| a | b |'), ['a', 'b'])
  call s:assert.equals(s:split('| a | b |   '), ['a', 'b'])
  call s:assert.equals(s:split('| a |  | '), ['a', ''])
endfunction

" ---- cell_index / vcell_index ----------------------------------------------

function! s:suite.cell_index() abort
  let l:line = '  | ab | c \| d | e |  '
  "             12345678901234567890123
  let l:want = repeat([0], 7) + repeat([1], 9) + repeat([2], 7)
  let l:got = map(range(1, len(l:line)), 'tableops#domain#table#cell_index(l:line, v:val)')
  call s:assert.equals(l:got, l:want)
endfunction

function! s:suite.cell_index_open_row() abort
  let l:line = '| a | b'
  call s:assert.equals(tableops#domain#table#cell_index(l:line, 5), 1)
  call s:assert.equals(tableops#domain#table#cell_index(l:line, 7), 1)
  call s:assert.equals(tableops#domain#table#cell_index(l:line, 99), 1)
endfunction

function! s:suite.cell_index_line_without_cells() abort
  call s:assert.equals(tableops#domain#table#cell_index('|', 1), 0)
  call s:assert.equals(tableops#domain#table#cell_index('abc', 2), 0)
endfunction

function! s:suite.vcell_index_full_width() abort
  " screen columns: |1 sp2 年3-4 齢5-6 sp7 |8 sp9 a10 sp11 |12
  let l:line = '| 年齢 | a |'
  call s:assert.equals(tableops#domain#table#vcell_index(l:line, 1), 0)
  call s:assert.equals(tableops#domain#table#vcell_index(l:line, 7), 0)
  call s:assert.equals(tableops#domain#table#vcell_index(l:line, 8), 1)
  call s:assert.equals(tableops#domain#table#vcell_index(l:line, 10), 1)
  call s:assert.equals(tableops#domain#table#vcell_index(l:line, 12), 1)
  call s:assert.equals(tableops#domain#table#vcell_index(l:line, 40), 1)
  " byte position of the second | is 10, not 8: by bytes it would differ
  call s:assert.equals(tableops#domain#table#cell_index(l:line, 8), 0)
endfunction

function! s:suite.vcell_index_left_of_table() abort
  call s:assert.equals(tableops#domain#table#vcell_index('   | a | b |', 1), 0)
endfunction

" ---- is_separator / align_of -----------------------------------------------

function! s:suite.is_separator() abort
  let l:T = function('tableops#domain#table#is_separator')
  call s:assert.true(l:T(s:split('|---|---|')))
  call s:assert.true(l:T(s:split('| --- | |')))
  call s:assert.true(l:T(s:split('|-|')))
  call s:assert.true(l:T(s:split('| - |')))
  call s:assert.true(l:T(s:split('|:-|-:|:-:|')))
  call s:assert.false(l:T(s:split('| | |')))
  call s:assert.false(l:T(s:split('| : |')))
  call s:assert.false(l:T(s:split('| -a- |')))
  call s:assert.false(l:T(s:split('| -- - |')))
  call s:assert.false(l:T(s:split('| ::- |')))
  call s:assert.false(l:T(s:split('| a |')))
endfunction

function! s:suite.align_of() abort
  let l:A = function('tableops#domain#table#align_of')
  call s:assert.equals(map(['---', ':--', '--:', ':-:', '', ':-', '-:'], 'l:A(v:val)'),
        \ ['', 'l', 'r', 'c', '', 'l', 'r'])
endfunction

" ---- parse -----------------------------------------------------------------

function! s:suite.parse_with_header() abort
  let l:r = tableops#domain#table#parse(s:example)
  call s:assert.equals(l:r, {'ok': 1, 'table': {
        \ 'indent': '',
        \ 'header': ['name', '年齢', 'city \| area'],
        \ 'align': ['l', 'r', 'c'],
        \ 'rows': [['foo', '12', 'tokyo']]}})
endfunction

function! s:suite.parse_without_header() abort
  let l:r = tableops#domain#table#parse(['| a | b |', '| c | d |'])
  call s:assert.equals(l:r.table, {'indent': '', 'header': [], 'align': ['', ''],
        \ 'rows': [['a', 'b'], ['c', 'd']]})
endfunction

function! s:suite.parse_one_line() abort
  let l:r = tableops#domain#table#parse(['  | a |'])
  call s:assert.equals(l:r.table, {'indent': '  ', 'header': [], 'align': [''], 'rows': [['a']]})
endfunction

function! s:suite.parse_ragged_rows() abort
  let l:r = tableops#domain#table#parse(['| a |', '|---|', '| b | c | d', '|', '| e | f |'])
  call s:assert.equals(l:r.table, {'indent': '',
        \ 'header': ['a', '', ''], 'align': ['', '', ''],
        \ 'rows': [['b', 'c', 'd'], ['', '', ''], ['e', 'f', '']]})
endfunction

function! s:suite.parse_wide_separator_row() abort
  let l:r = tableops#domain#table#parse(['| a |', '|---|--:|'])
  call s:assert.equals(l:r.table, {'indent': '', 'header': ['a', ''], 'align': ['', 'r'], 'rows': []})
endfunction

function! s:suite.parse_separator_with_empty_cell() abort
  let l:r = tableops#domain#table#parse(['| a | b |', '| --- | |', '| c | d |'])
  call s:assert.equals(l:r.table.header, ['a', 'b'])
  call s:assert.equals(l:r.table.align, ['', ''])
endfunction

function! s:suite.parse_malformed() abort
  call s:assert.equals(tableops#domain#table#parse(['|---|', '| a |']), {'ok': 0, 'code': 'malformed'})
  call s:assert.equals(tableops#domain#table#parse(['| :-: |']), {'ok': 0, 'code': 'malformed'})
endfunction

function! s:suite.parse_crlf() abort
  call s:assert.equals(tableops#domain#table#parse(['| a |', "| b |\r"]), {'ok': 0, 'code': 'crlf'})
  call s:assert.equals(tableops#domain#table#parse(["|---|\r"]), {'ok': 0, 'code': 'crlf'})
endfunction

function! s:suite.parse_indent_is_from_first_line() abort
  let l:r = tableops#domain#table#parse([" \t| a |", '| b |'])
  call s:assert.equals(l:r.table.indent, " \t")
endfunction

function! s:suite.parse_does_not_change_input() abort
  let l:lines = copy(s:example)
  call tableops#domain#table#parse(l:lines)
  call s:assert.equals(l:lines, s:example)
endfunction

" ---- render ----------------------------------------------------------------

function! s:suite.render_example() abort
  let l:r = tableops#domain#table#parse(s:example)
  call s:assert.equals(tableops#domain#table#render(l:r.table), s:example)
endfunction

function! s:suite.render_ragged() abort
  call s:assert.equals(s:roundtrip(['| a |', '|---|', '| bbb | c', '|']), [
        \ '| a   |   |',
        \ '|-----|---|',
        \ '| bbb | c |',
        \ '|     |   |'])
endfunction

function! s:suite.render_empty_columns_are_one_wide() abort
  call s:assert.equals(s:roundtrip(['||', '|-|']), ['|   |', '|---|'])
endfunction

function! s:suite.render_aligns() abort
  call s:assert.equals(s:roundtrip(['| a | b | c | d |', '|---|:--|--:|:-:|', '| xyz | xyz | xyz | xyz |']), [
        \ '| a   | b   |   c | d   |',
        \ '|-----|:----|----:|:---:|',
        \ '| xyz | xyz | xyz | xyz |'])
endfunction

let s:roundtrips = {
      \ 'formatted': ['| a   | b  |', '|-----|----|', '| ccc | dd |'],
      \ 'full_width': ['| 名前 | 年齢 |', '|------|------|', '| 太郎 | 20   |', '| ab   | 1    |'],
      \ 'escaped_pipe': ['| a \| b | c   |', '|--------|-----|', '| x      | \|y |'],
      \ 'aligns': ['| a   | b   |   c | d   |', '|-----|:----|----:|:---:|', '| xyz | xyz | xyz | xyz |'],
      \ 'indent': ['  | a | b |', '  |---|---|', '  | c | d |'],
      \ 'tab_indent': ["\t| a |", "\t|---|", "\t| b |"],
      \ 'no_header': ['| a  | b |', '| cc | d |'],
      \ 'one_row': ['| a |'],
      \ 'example': s:example,
      \ }

function! s:suite.render_parse_roundtrip() abort
  for [l:name, l:lines] in items(s:roundtrips)
    call s:assert.equals(s:roundtrip(l:lines), l:lines, l:name)
  endfor
endfunction

function! s:suite.render_twice_is_the_same() abort
  for l:lines in [['|a|b', '|:-:|', '|  ccc |'], ['  | 全角 |x', '| y |'], ['| a \| b | c', '|-|-:|-|', '|']]
    let l:once = s:roundtrip(l:lines)
    call s:assert.equals(s:roundtrip(l:once), l:once, string(l:lines))
  endfor
endfunction

function! s:suite.render_does_not_add_a_separator() abort
  call s:assert.equals(s:roundtrip(['|a|', '|b|']), ['| a |', '| b |'])
endfunction

function! s:suite.cell_index_of_empty_cells() abort
  " the | right of an empty cell belongs to it: the cursor stands there
  let l:line = '|a||b|'
  call s:assert.equals(map(range(1, 6), 'tableops#domain#table#cell_index(l:line, v:val)'),
        \ [0, 0, 1, 1, 2, 2])
  call s:assert.equals(map(range(1, 6), 'tableops#domain#table#vcell_index(l:line, v:val)'),
        \ [0, 0, 1, 1, 2, 2])
  call s:assert.equals(map(range(1, 3), 'tableops#domain#table#cell_index("|||", v:val)'),
        \ [0, 0, 1])
  call s:assert.equals(map(range(1, 4), 'tableops#domain#table#cell_index("|a||", v:val)'),
        \ [0, 0, 1, 1])
  " cell_start() of every cell maps back to that cell
  for l:line in ['|a||b|', '|||', '| a ||| b', '||x||']
    let l:n = len(s:spans(l:line))
    call s:assert.equals(map(range(l:n), 'tableops#domain#table#cell_index(l:line, tableops#app#table#cell_start(l:line, v:val))'),
          \ range(l:n), l:line)
  endfor
endfunction

function! s:suite.x01_with_a_long_cell_is_fast_and_does_not_throw() abort
  " the slow path walks the line without a regexp (E363 before)
  let l:long = repeat('x', 100000)
  for l:tail in [' | b |', ' | b \| c |', '\| b \\| c', ' |']
    let l:line = '| ' . l:long . "\x01" . l:tail
    let l:same = '| ' . l:long . 'y' . l:tail
    let l:t = reltime()
    let l:a = s:spans(l:line)
    call s:assert.true(reltimefloat(reltime(l:t)) < 2.0, l:tail)
    call s:assert.equals(map(l:a, '[v:val.pipe, v:val.start, v:val.end, v:val.close]'),
          \ map(s:spans(l:same), '[v:val.pipe, v:val.start, v:val.end, v:val.close]'), l:tail)
    call s:assert.equals(len(s:split(l:line)), len(s:split(l:same)))
  endfor
endfunction

function! s:suite.x01_slow_path_agrees_with_the_fast_path() abort
  " every line of the alphabet up to 4 pieces, with 'a' made \x01
  let l:alpha = ['|', '\', 'a', ' ', '-']
  let l:lines = ['']
  for l:_ in range(5)
    let l:next = []
    for l:l in l:lines
      call extend(l:next, map(copy(l:alpha), 'l:l . v:val'))
    endfor
    let l:lines += l:next
    let l:lines = uniq(sort(l:lines))
  endfor
  for l:line in l:lines
    let l:x = substitute(l:line, 'a', "\x01", 'g')
    if l:x ==# l:line
      continue
    endif
    let l:a = map(s:spans(l:line), '[v:val.pipe, v:val.start, v:val.end, v:val.close]')
    let l:b = map(s:spans(l:x), '[v:val.pipe, v:val.start, v:val.end, v:val.close]')
    call s:assert.equals(l:b, l:a, string(l:line))
  endfor
endfunction
