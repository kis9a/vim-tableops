scriptencoding utf-8

let s:suite = themis#suite('domain_column')
let s:assert = themis#helper('assert')

function! s:table() abort
  return {'indent': '', 'header': ['h1', 'h2', 'h3', 'h4'], 'align': ['l', 'r', 'c', ''],
        \ 'rows': [['a1', 'a2', 'a3', 'a4'], ['b1', 'b2', 'b3', 'b4']]}
endfunction

function! s:col(t, i) abort
  return map(copy(a:t.rows), 'v:val[a:i]')
endfunction

" ---- delete ----------------------------------------------------------------

function! s:suite.delete_one() abort
  let l:t = tableops#domain#column#delete(s:table(), [1])
  call s:assert.equals(l:t, {'indent': '', 'header': ['h1', 'h3', 'h4'], 'align': ['l', 'c', ''],
        \ 'rows': [['a1', 'a3', 'a4'], ['b1', 'b3', 'b4']]})
endfunction

function! s:suite.delete_many_in_any_order_with_duplicates() abort
  let l:want = {'indent': '', 'header': ['h1', 'h3'], 'align': ['l', 'c'],
        \ 'rows': [['a1', 'a3'], ['b1', 'b3']]}
  call s:assert.equals(tableops#domain#column#delete(s:table(), [1, 3]), l:want)
  call s:assert.equals(tableops#domain#column#delete(s:table(), [3, 1]), l:want)
  call s:assert.equals(tableops#domain#column#delete(s:table(), [3, 1, 1, 3]), l:want)
endfunction

function! s:suite.delete_without_header() abort
  let l:t = {'indent': ' ', 'header': [], 'align': ['', ''], 'rows': [['a', 'b']]}
  call s:assert.equals(tableops#domain#column#delete(l:t, [0]),
        \ {'indent': ' ', 'header': [], 'align': [''], 'rows': [['b']]})
endfunction

function! s:suite.delete_requirement_example() abort
  let l:lines = [
        \ '| name | 年齢 | city \| area |',
        \ '|:-----|-----:|:------------:|',
        \ '| foo  |   12 | tokyo        |']
  let l:t = tableops#domain#table#parse(l:lines).table
  call s:assert.equals(tableops#domain#table#render(tableops#domain#column#delete(l:t, [1])), [
        \ '| name | city \| area |',
        \ '|:-----|:------------:|',
        \ '| foo  | tokyo        |'])
endfunction

" ---- insert / move ---------------------------------------------------------

function! s:suite.insert() abort
  let l:t = tableops#domain#column#insert(s:table(), 0)
  call s:assert.equals(l:t.header, ['', 'h1', 'h2', 'h3', 'h4'])
  call s:assert.equals(l:t.align, ['', 'l', 'r', 'c', ''])
  call s:assert.equals(l:t.rows[1], ['', 'b1', 'b2', 'b3', 'b4'])
  let l:t = tableops#domain#column#insert(s:table(), 2)
  call s:assert.equals(l:t.header, ['h1', 'h2', '', 'h3', 'h4'])
  let l:t = tableops#domain#column#insert(s:table(), 4)
  call s:assert.equals(l:t.header, ['h1', 'h2', 'h3', 'h4', ''])
  call s:assert.equals(l:t.align, ['l', 'r', 'c', '', ''])
  call s:assert.equals(l:t.rows[0], ['a1', 'a2', 'a3', 'a4', ''])
endfunction

function! s:suite.insert_without_header() abort
  let l:t = {'indent': '', 'header': [], 'align': [''], 'rows': [['a']]}
  call s:assert.equals(tableops#domain#column#insert(l:t, 1),
        \ {'indent': '', 'header': [], 'align': ['', ''], 'rows': [['a', '']]})
endfunction

function! s:suite.move() abort
  let l:t = tableops#domain#column#move(s:table(), 0, 2)
  call s:assert.equals(l:t.header, ['h2', 'h3', 'h1', 'h4'])
  call s:assert.equals(l:t.align, ['r', 'c', 'l', ''])
  call s:assert.equals(l:t.rows, [['a2', 'a3', 'a1', 'a4'], ['b2', 'b3', 'b1', 'b4']])
  let l:t = tableops#domain#column#move(s:table(), 3, 0)
  call s:assert.equals(l:t.header, ['h4', 'h1', 'h2', 'h3'])
  let l:t = tableops#domain#column#move(s:table(), 1, 1)
  call s:assert.equals(l:t, s:table())
endfunction

function! s:suite.move_without_header() abort
  let l:t = {'indent': '', 'header': [], 'align': ['', ''], 'rows': [['a', 'b']]}
  call s:assert.equals(tableops#domain#column#move(l:t, 0, 1).rows, [['b', 'a']])
endfunction

function! s:suite.transforms_do_not_change_input() abort
  let l:t = s:table()
  call tableops#domain#column#delete(l:t, [0, 2])
  call tableops#domain#column#insert(l:t, 1)
  call tableops#domain#column#move(l:t, 0, 3)
  call tableops#domain#column#sort(l:t, 0, {'reverse': 1})
  call s:assert.equals(l:t, s:table())
  let l:idxs = [3, 1, 1]
  call tableops#domain#column#delete(l:t, l:idxs)
  call s:assert.equals(l:idxs, [3, 1, 1])
endfunction

" ---- sort ------------------------------------------------------------------

function! s:sorted(cells, opts) abort
  let l:t = {'indent': '', 'header': ['k', 'id'], 'align': ['', ''],
        \ 'rows': map(copy(a:cells), '[v:val, string(v:key)]')}
  let l:s = tableops#domain#column#sort(l:t, 0, a:opts)
  call s:assert.equals(l:s.header, ['k', 'id'])
  return map(l:s.rows, 'v:val[0] . "#" . v:val[1]')
endfunction

function! s:suite.sort_string_is_byte_order() abort
  call s:assert.equals(s:sorted(['b', 'B', 'a', 'A', '10', '9'], {}),
        \ ['10#4', '9#5', 'A#3', 'B#1', 'a#2', 'b#0'])
endfunction

function! s:suite.sort_icase_is_stable() abort
  call s:assert.equals(s:sorted(['b', 'B', 'a', 'A'], {'icase': 1}),
        \ ['a#2', 'A#3', 'b#0', 'B#1'])
endfunction

function! s:suite.sort_numeric() abort
  call s:assert.equals(s:sorted(['10', '9', 'x', '-3.5', '9', 'v2', '1,000', ''], {'numeric': 1}),
        \ ['x#2', '#7', '-3.5#3', '1,000#6', 'v2#5', '9#1', '9#4', '10#0'])
endfunction

function! s:suite.sort_numeric_reverse() abort
  " equal keys keep their order; cells without a number go last
  call s:assert.equals(s:sorted(['10', '9', 'x', '-3.5', '9', ''], {'numeric': 1, 'reverse': 1}),
        \ ['10#0', '9#1', '9#4', '-3.5#3', 'x#2', '#5'])
endfunction

function! s:suite.sort_reverse_string_is_stable() abort
  call s:assert.equals(s:sorted(['a', 'b', 'a', 'c', 'b'], {'reverse': 1}),
        \ ['c#3', 'b#1', 'b#4', 'a#0', 'a#2'])
endfunction

function! s:suite.sort_numeric_wins_over_icase() abort
  call s:assert.equals(s:sorted(['B', 'a', '2', '1'], {'numeric': 1, 'icase': 1}),
        \ ['B#0', 'a#1', '1#3', '2#2'])
endfunction

function! s:suite.sort_stable_with_many_equal_keys() abort
  let l:cells = map(range(300), 'string(v:val % 3)')
  let l:got = s:sorted(l:cells, {'numeric': 1})
  let l:want = []
  for l:k in range(3)
    let l:want += map(filter(range(300), 'v:val % 3 == l:k'), 'l:k . "#" . v:val')
  endfor
  call s:assert.equals(l:got, l:want)
  let l:got = s:sorted(l:cells, {'reverse': 1})
  let l:want = []
  for l:k in [2, 1, 0]
    let l:want += map(filter(range(300), 'v:val % 3 == l:k'), 'l:k . "#" . v:val')
  endfor
  call s:assert.equals(l:got, l:want)
endfunction

function! s:suite.sort_numeric_edges() abort
  call s:assert.equals(s:sorted(['-1', '-1.5', '-1.4', '-0', '0', '0.5', '007', '7', '1.50', '1.5', '-10', '-9'], {'numeric': 1}),
        \ ['-10#10', '-9#11', '-1.5#1', '-1.4#2', '-1#0', '-0#3', '0#4', '0.5#5', '1.50#8', '1.5#9', '007#6', '7#7'])
endfunction

" The same order as a comparator on str2float() keys with the index as the
" tie break (the definition in the plan), over many cells.
function! s:reference(a, b) abort dict
  let [l:ka, l:kb] = [a:a[0], a:b[0]]
  if l:ka[0] != l:kb[0]
    return (l:ka[0] - l:kb[0]) * self.sign
  elseif l:ka[1] != l:kb[1]
    return (l:ka[1] < l:kb[1] ? -1 : 1) * self.sign
  endif
  return a:a[1] - a:b[1]
endfunction

function! s:suite.sort_numeric_matches_str2float() abort
  let l:cells = map(range(400), 'v:val % 9 == 0 ? "n/a" : printf("x%d.%d", (v:val * 37 % 41) - 20, v:val * 7 % 10)')
  for l:sign in [1, -1]
    let l:keyed = map(copy(l:cells), 'v:val =~# "\\d" ? [[1, str2float(matchstr(v:val, "-\\=\\d\\+\\%(\\.\\d\\+\\)\\="))], v:key] : [[0, 0.0], v:key]')
    call sort(l:keyed, function('s:reference'), {'sign': l:sign})
    let l:want = map(l:keyed, 'l:cells[v:val[1]] . "#" . v:val[1]')
    call s:assert.equals(s:sorted(l:cells, {'numeric': 1, 'reverse': l:sign < 0}), l:want)
  endfor
endfunction

function! s:suite.sort_string_with_x01() abort
  call s:assert.equals(s:sorted(["a\x01", 'a', "a\x01b", "\x02", "\x01", 'a'], {}),
        \ ["\x01#4", "\x02#3", 'a#1', 'a#5', "a\x01#0", "a\x01b#2"])
endfunction

function! s:suite.sort_string_prefix_and_multibyte() abort
  call s:assert.equals(s:sorted(['ab', 'a', "a\tb", 'a b', '年', 'z'], {}),
        \ ['a#1', "a\tb#2", 'a b#3', 'ab#0', 'z#5', '年#4'])
endfunction

function! s:suite.sort_by_middle_column_keeps_rows_whole() abort
  let l:t = tableops#domain#column#sort(s:table(), 2, {'reverse': 1})
  call s:assert.equals(l:t.rows, [['b1', 'b2', 'b3', 'b4'], ['a1', 'a2', 'a3', 'a4']])
  call s:assert.equals(l:t.align, ['l', 'r', 'c', ''])
endfunction

" ---- pattern (D6) ----------------------------------------------------------

function! s:suite.pattern_text() abort
  let l:c = '%(\\\||\\%(\|)@!|[^|\\])'
  call s:assert.equals(tableops#domain#column#pattern(1),
        \ '\v^\s*%(\|' . l:c . '*){1}\zs\|%(\s*$)@!' . l:c . '*')
  call s:assert.match(tableops#domain#column#pattern(0), '{0}')
endfunction

let s:rows = [
      \ '| a | b | c |',
      \ '| a | b | c',
      \ '|a|b|c|',
      \ '| a | b |',
      \ '| a |',
      \ '| a | ',
      \ '| a |   |',
      \ '| a || c |',
      \ '||||',
      \ '|',
      \ '  | a | b | c |  ',
      \ "\t| a\t|\tb |",
      \ '| a \| x | b \| y | c |',
      \ '| a \\| x | b | c |',
      \ '| a \\\| x | b \\ | c |',
      \ '| \ | \\ | \a |',
      \ '| a\ | b\ | c\',
      \ '| 年齢 | 全角 \| x | c |',
      \ '|:--|--:|:-:|',
      \ '| a | b | c | d | e |',
      \ ]

" For each row and column, the pattern matches the | and the raw text of
" that cell (as spans() sees it), or nothing when the row has no such cell.
function! s:suite.pattern_matches_the_cell_of_each_row() abort
  for l:idx in range(6)
    let l:pat = tableops#domain#column#pattern(l:idx)
    for l:row in s:rows
      let l:spans = tableops#domain#table#spans(l:row)
      let l:got = matchstrpos(l:row, l:pat)
      let l:msg = printf('column %d of %s', l:idx + 1, string(l:row))
      if l:idx < len(l:spans) && !(l:idx == len(l:spans) - 1 && l:spans[l:idx].close == 0 && l:spans[l:idx].text ==# '')
        let l:s = l:spans[l:idx]
        call s:assert.equals(l:got, ['|' . l:s.text, l:s.pipe - 1, l:s.end], l:msg)
      else
        call s:assert.equals(l:got[1], -1, l:msg)
      endif
    endfor
  endfor
endfunction

function! s:suite.pattern_skips_the_closing_pipe() abort
  " N-1 cells and a closing | : no column N
  call s:assert.equals(matchstrpos('| a | b |', tableops#domain#column#pattern(2))[1], -1)
  call s:assert.equals(matchstrpos('| a | b |  ', tableops#domain#column#pattern(2))[1], -1)
  call s:assert.equals(matchstrpos('| a |', tableops#domain#column#pattern(1))[1], -1)
endfunction

function! s:suite.pattern_escaped_pipes() abort
  call s:assert.equals(matchstr('| a \| x | b |', tableops#domain#column#pattern(0)), '| a \| x ')
  call s:assert.equals(matchstr('| a \| x | b |', tableops#domain#column#pattern(1)), '| b ')
  call s:assert.equals(matchstr('| a \\| x | b |', tableops#domain#column#pattern(0)), '| a \\| x ')
  call s:assert.equals(matchstr('| a \\| x | b |', tableops#domain#column#pattern(1)), '| b ')
endfunction

function! s:suite.pattern_in_a_buffer_with_nomagic_and_ignorecase() abort
  call TableopsTestBuffer(['| A | b |', '| a \| x | B |', '| a |'])
  let l:save = [&magic, &ignorecase, &smartcase]
  try
    set nomagic ignorecase smartcase
    let l:pat = tableops#domain#column#pattern(1)
    call cursor(1, 1)
    call s:assert.equals(searchpos(l:pat, 'cW'), [1, 5])
    call s:assert.equals(searchpos(l:pat, 'W'), [2, 10])
    call s:assert.equals(searchpos(l:pat, 'W'), [0, 0])
  finally
    let [&magic, &ignorecase, &smartcase] = l:save
  endtry
endfunction

" ---- argument parsing ------------------------------------------------------

function! s:suite.parse_columns() abort
  let l:P = function('tableops#domain#column#parse_columns')
  call s:assert.equals(l:P('', 3), {'ok': 1, 'idxs': []})
  call s:assert.equals(l:P('2', 3), {'ok': 1, 'idxs': [1]})
  call s:assert.equals(l:P(' 2  4 ', 4), {'ok': 1, 'idxs': [1, 3]})
  call s:assert.equals(l:P('4 2 2', 4), {'ok': 1, 'idxs': [1, 3]})
  call s:assert.equals(l:P('010', 10), {'ok': 1, 'idxs': [9]})
  call s:assert.equals(l:P('0', 3), {'ok': 0, 'code': 'bad_column', 'arg': '0'})
  call s:assert.equals(l:P('1 4', 3), {'ok': 0, 'code': 'bad_column', 'arg': '4'})
  call s:assert.equals(l:P('-1', 3), {'ok': 0, 'code': 'bad_column', 'arg': '-1'})
  call s:assert.equals(l:P('x', 3), {'ok': 0, 'code': 'bad_column', 'arg': 'x'})
  call s:assert.equals(l:P('1.5', 3), {'ok': 0, 'code': 'bad_column', 'arg': '1.5'})
endfunction

function! s:suite.parse_sort_args() abort
  let l:P = function('tableops#domain#column#parse_sort_args')
  call s:assert.equals(l:P('', 3), {'ok': 1, 'idx': -1, 'numeric': 0, 'icase': 0})
  call s:assert.equals(l:P('3 n', 3), {'ok': 1, 'idx': 2, 'numeric': 1, 'icase': 0})
  call s:assert.equals(l:P('in', 3), {'ok': 1, 'idx': -1, 'numeric': 1, 'icase': 1})
  call s:assert.equals(l:P('i 1', 3), {'ok': 1, 'idx': 0, 'numeric': 0, 'icase': 1})
  call s:assert.equals(l:P('n i', 3), {'ok': 1, 'idx': -1, 'numeric': 1, 'icase': 1})
  call s:assert.equals(l:P('4', 3), {'ok': 0, 'code': 'bad_column', 'arg': '4'})
  call s:assert.equals(l:P('0 n', 3), {'ok': 0, 'code': 'bad_column', 'arg': '0'})
  call s:assert.equals(l:P('1 2', 3), {'ok': 0, 'code': 'bad_args', 'arg': '2'})
  call s:assert.equals(l:P('x', 3), {'ok': 0, 'code': 'bad_args', 'arg': 'x'})
  call s:assert.equals(l:P('-1', 3), {'ok': 0, 'code': 'bad_args', 'arg': '-1'})
  call s:assert.equals(l:P('nr', 3), {'ok': 0, 'code': 'bad_args', 'arg': 'nr'})
endfunction

function! s:suite.parse_delta() abort
  let l:P = function('tableops#domain#column#parse_delta')
  call s:assert.equals(l:P('1'), 1)
  call s:assert.equals(l:P('+2'), 2)
  call s:assert.equals(l:P('-3'), -3)
  call s:assert.equals(l:P(' -1 '), -1)
  call s:assert.equals(l:P('0'), 0)
  call s:assert.equals(l:P('08'), 8)
  call s:assert.same(l:P(''), v:null)
  call s:assert.same(l:P('x'), v:null)
  call s:assert.same(l:P('+'), v:null)
  call s:assert.same(l:P('1.5'), v:null)
  call s:assert.same(l:P('--1'), v:null)
endfunction
