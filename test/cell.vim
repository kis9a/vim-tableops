scriptencoding utf-8

let s:suite = themis#suite('cell')
let s:assert = themis#helper('assert')

" Byte columns: a 3, bb 8, c 13; 1 3, 2 8, 3 13; the row of line 5 is short.
let s:T = [
      \ 'intro',
      \ '| a  | bb | c |',
      \ '|----|----|---|',
      \ '| 1  | 2  | 3 |',
      \ '| 4  | 5  |',
      \ '| 7  | 8  | 9 |',
      \ 'outro']

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  let @" = 'keep'
  messages clear
endfunction

function! s:suite.after_each() abort
  set selection&
endfunction

function! s:pos() abort
  return [line('.'), col('.')]
endfunction

" Run {keys} where <L> <R> <U> <D> <I> <A> are the <Plug> mappings.
function! s:keys(keys) abort
  let l:k = a:keys
  for [l:from, l:to] in [['<L>', 'cell-left'], ['<R>', 'cell-right'], ['<U>', 'cell-up'],
        \ ['<D>', 'cell-down'], ['<I>', 'inner-cell'], ['<A>', 'a-cell']]
    let l:k = substitute(l:k, l:from, "\<Plug>(tableops-" . l:to . ')', 'g')
  endfor
  execute 'normal ' . l:k
endfunction

function! s:from(lnum, col, keys) abort
  call cursor(a:lnum, a:col)
  call s:keys(a:keys)
  return s:pos()
endfunction

" ---- n mode ------------------------------------------------------------------

function! s:suite.right_and_left_wrap_and_skip_the_separator() abort
  call s:assert.equals(s:from(2, 3, '<R>'), [2, 8])
  call s:assert.equals(s:from(2, 13, '<R>'), [4, 3])
  call s:assert.equals(s:from(5, 8, '<R>'), [6, 3])
  call s:assert.equals(s:from(4, 3, '<L>'), [2, 13])
  call s:assert.equals(s:from(6, 3, '<L>'), [5, 8])
  call s:assert.equals(s:from(2, 9, '<L>'), [2, 3])
  " from the | or the blanks of a cell
  call s:assert.equals(s:from(4, 6, '<R>'), [4, 13])
  call s:assert.equals(s:from(4, 1, '<R>'), [4, 8])
endfunction

function! s:suite.up_and_down_skip_the_separator_and_keep_the_column() abort
  call s:assert.equals(s:from(2, 13, '<D>'), [4, 13])
  call s:assert.equals(s:from(4, 3, '<U>'), [2, 3])
  call s:assert.equals(s:from(4, 13, '<D>'), [5, 8])
  " the count keeps the column across the short row
  call s:assert.equals(s:from(2, 13, '3<D>'), [6, 13])
  call s:assert.equals(s:from(6, 13, '3<U>'), [2, 13])
endfunction

function! s:suite.count() abort
  call s:assert.equals(s:from(2, 3, '3<R>'), [4, 3])
  call s:assert.equals(s:from(6, 13, '4<L>'), [5, 3])
  " as far as it goes
  call s:assert.equals(s:from(4, 8, '9<R>'), [6, 13])
endfunction

function! s:suite.stop_at_the_ends_without_a_leftover_count() abort
  call s:assert.equals(s:from(6, 13, '<R>'), [6, 13])
  call s:assert.equals(s:from(2, 3, '<L>'), [2, 3])
  call s:assert.equals(s:from(2, 8, '<U>'), [2, 8])
  call s:assert.equals(s:from(6, 8, '<D>'), [6, 8])
  " x deletes one character, not 3
  call s:from(6, 13, '3<R>x')
  call s:assert.equals(getline(6), '| 7  | 8  |  |')
  call s:from(2, 3, '3<U>x')
  call s:assert.equals(getline(2), '|   | bb | c |')
  call s:assert.equals(TableopsTestMessage() =~# 'tableops', 0)
endfunction

function! s:suite.outside_a_table() abort
  call s:assert.equals(s:from(1, 2, '<R>'), [1, 2])
  call s:assert.equals(TableopsTestMessage(), '[tableops] not in a table')
  messages clear
  call s:assert.equals(s:from(7, 1, '3<D>x'), [7, 1])
  call s:assert.equals(getline(7), 'utro')
  call s:assert.equals(TableopsTestMessage(), '[tableops] not in a table')
endfunction

function! s:suite.headerless_tables_skip_no_row() abort
  call TableopsTestBuffer(['| a |', '| b |', '| - |', '| c |'])
  call s:assert.equals(s:from(2, 3, '<D>'), [3, 3])
  call s:assert.equals(s:from(1, 3, '<D>'), [2, 3])
  " the second line is a separator: then it is skipped
  call TableopsTestBuffer(['| a |', '| - |', '| c |'])
  call s:assert.equals(s:from(1, 3, '<D>'), [3, 3])
  call s:assert.equals(s:from(1, 3, '<R>'), [3, 3])
endfunction

function! s:suite.cells_of_blanks_and_full_width() abort
  call TableopsTestBuffer(['| 年齢 |    | x |'])
  " a cell of blanks: one blank after its |
  call s:assert.equals(s:from(1, 1, '<R>'), [1, 12])
  call s:assert.equals(s:from(1, 12, '<R>'), [1, 17])
  call s:assert.equals(s:from(1, 17, '<L><L>'), [1, 3])
endfunction

" ---- x mode ------------------------------------------------------------------

function! s:suite.visual_extends_and_wraps() abort
  call cursor(4, 3)
  call s:keys("v<R>\<Esc>")
  call s:assert.equals([getpos("'<")[1 : 2], getpos("'>")[1 : 2]], [[4, 3], [4, 8]])
  call cursor(4, 13)
  call s:keys("v<R>\<Esc>")
  call s:assert.equals([getpos("'<")[1 : 2], getpos("'>")[1 : 2]], [[4, 13], [5, 3]])
  call cursor(2, 3)
  call s:keys("v2<D>\<Esc>")
  call s:assert.equals(getpos("'>")[1 : 2], [5, 3])
  " stopped: the selection stays, no count is left
  call cursor(6, 8)
  call s:keys("v3<D>d")
  call s:assert.equals(getline(6), '| 7  |   | 9 |')
endfunction

" ---- o mode ------------------------------------------------------------------

function! s:suite.operator_right_and_left_stay_on_the_row() abort
  call s:from(4, 3, 'd<R>')
  call s:assert.equals(getline(4), '| 2  | 3 |')
  call TableopsTestBuffer(s:T)
  call s:from(4, 13, 'd<L>')
  call s:assert.equals(getline(4), '| 1  | 3 |')
  " at the end of the row: nothing
  call TableopsTestBuffer(s:T)
  call s:from(4, 13, 'd<R>')
  call s:from(4, 3, 'd<L>')
  call s:assert.equals(TableopsTestLines(), s:T)
  " a count
  call s:from(4, 3, '2d<R>')
  call s:assert.equals(getline(4), '| 3 |')
  call TableopsTestBuffer(s:T)
  call s:from(4, 3, 'd2<R>')
  call s:assert.equals(getline(4), '| 3 |')
  " more than the row has: as far as it goes
  call TableopsTestBuffer(s:T)
  call s:from(4, 3, 'd5<R>')
  call s:assert.equals(getline(4), '| 3 |')
endfunction

function! s:suite.operator_up_and_down_are_linewise() abort
  call s:from(4, 3, 'd<D>')
  call s:assert.equals(TableopsTestLines(), s:T[0 : 2] + s:T[5 :])
  call TableopsTestBuffer(s:T)
  call s:from(6, 8, 'd<U>')
  call s:assert.equals(TableopsTestLines(), s:T[0 : 3] + s:T[6 :])
  call TableopsTestBuffer(s:T)
  call s:from(6, 8, 'd<D>')
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

" . sees only a change made by :normal in this function, not in a helper.
function! s:suite.operator_dot_is_relative_to_the_new_cursor() abort
  call cursor(4, 3)
  execute "normal d\<Plug>(tableops-cell-right)"
  call cursor(6, 3)
  normal .
  call s:assert.equals(getline(4), '| 2  | 3 |')
  call s:assert.equals(getline(6), '| 8  | 9 |')
  " linewise
  call TableopsTestBuffer(['| a |', '|---|', '| 1 |', '| 2 |', '| 3 |', '| 4 |', '| 5 |'])
  call cursor(3, 3)
  execute "normal d\<Plug>(tableops-cell-down)"
  call cursor(4, 3)
  normal .
  call s:assert.equals(TableopsTestLines(), ['| a |', '|---|', '| 3 |'])
endfunction

function! s:suite.operator_without_a_target_changes_nothing() abort
  " at the edge of the row and outside the table: c y d do nothing
  for [l:lnum, l:col] in [[4, 13], [1, 2], [3, 2]]
    for l:keys in ['c<R>zz', 'y<R>', 'd<R>', 'c<D>zz', 'y<I>', 'c<I>zz', 'y<A>']
      if l:lnum == 4 && l:keys =~# 'D\|I\|A'
        continue
      endif
      call TableopsTestBuffer(s:T)
      let @" = 'keep'
      call s:from(l:lnum, l:col, l:keys)
      call s:assert.equals(TableopsTestLines(), s:T, l:lnum . l:keys)
      call s:assert.equals(@", 'keep', l:lnum . l:keys)
    endfor
  endfor
  call s:from(6, 3, 'c<D>zz')
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

" ---- text objects ------------------------------------------------------------

function! s:suite.inner_and_a_cell() abort
  call s:from(2, 9, 'y<I>')
  call s:assert.equals(@", 'bb')
  call s:from(2, 9, 'y<A>')
  call s:assert.equals(@", ' bb |')
  call s:from(4, 1, 'y<I>')
  call s:assert.equals(@", '1')
  call s:from(4, 15, 'y<I>')
  call s:assert.equals(@", '3')
endfunction

function! s:suite.change_inner_cell_and_dot() abort
  call cursor(2, 8)
  execute "normal c\<Plug>(tableops-inner-cell)X\<Esc>"
  call s:assert.equals(getline(2), '| a  | X | c |')
  call cursor(4, 13)
  normal .
  call s:assert.equals(getline(4), '| 1  | 2  | X |')
endfunction

function! s:suite.cells_of_every_shape() abort
  " blanks only: all of them
  call TableopsTestBuffer(['| a |   | b |'])
  call s:from(1, 7, 'y<I>')
  call s:assert.equals(@", '   ')
  " || : nothing to select
  call TableopsTestBuffer(['| a || b |'])
  let @" = 'keep'
  call s:from(1, 5, 'y<I>')
  call s:assert.equals(@", 'keep')
  call s:from(1, 5, 'c<I>zz')
  call s:assert.equals(getline(1), '| a || b |')
  " no closing |
  call TableopsTestBuffer(['| a | b'])
  call s:from(1, 7, 'y<I>')
  call s:assert.equals(@", 'b')
  call s:from(1, 7, 'y<A>')
  call s:assert.equals(@", ' b')
  " full width
  call TableopsTestBuffer(['| 年齢 | x |'])
  call s:from(1, 4, 'y<I>')
  call s:assert.equals(@", '年齢')
  call s:from(1, 4, 'y<A>')
  call s:assert.equals(@", ' 年齢 |')
  " \| is part of the cell
  call TableopsTestBuffer(['| a \| b | c |'])
  call s:from(1, 3, 'y<I>')
  call s:assert.equals(@", 'a \| b')
endfunction

function! s:suite.selection_exclusive() abort
  set selection=exclusive
  call s:from(2, 9, 'y<I>')
  call s:assert.equals(@", 'bb')
  call s:from(2, 9, 'y<A>')
  call s:assert.equals(@", ' bb |')
  call TableopsTestBuffer(['| 年齢 | x'])
  call s:from(1, 4, 'y<I>')
  call s:assert.equals(@", '年齢')
  call s:from(1, 12, 'y<A>')
  call s:assert.equals(@", ' x')
  call s:from(1, 4, 'c<I>X')
  call s:assert.equals(getline(1), '| X | x')
endfunction

function! s:suite.visual_text_objects() abort
  call cursor(2, 8)
  call s:keys("v<I>\<Esc>")
  call s:assert.equals([getpos("'<")[1 : 2], getpos("'>")[1 : 2]], [[2, 8], [2, 9]])
  call cursor(2, 8)
  call s:keys('v<A>d')
  call s:assert.equals(getline(2), '| a  | c |')
  " nothing to select: the selection stays
  call cursor(1, 1)
  call s:keys("vl<I>\<Esc>")
  call s:assert.equals([getpos("'<")[1 : 2], getpos("'>")[1 : 2]], [[1, 1], [1, 2]])
endfunction

" ---- empty cells (||) ----------------------------------------------------------

function! s:suite.motions_over_empty_cells() abort
  " the cursor of an empty cell is its closing |
  call TableopsTestBuffer(['|a||b|', '|c|d|e|'])
  call s:assert.equals(s:from(1, 2, '<R>'), [1, 4])
  call s:assert.equals(s:from(1, 4, '<R>'), [1, 5])
  call s:assert.equals(s:from(1, 2, '3<R>'), [2, 2])
  call s:assert.equals(s:from(1, 5, '<L>'), [1, 4])
  call s:assert.equals(s:from(1, 4, '<L>'), [1, 2])
  call s:assert.equals(s:from(1, 5, '2<L>'), [1, 2])
  call s:assert.equals(s:from(2, 2, '<L>'), [1, 5])
  call s:assert.equals(s:from(1, 4, '<D>'), [2, 4])
  call s:assert.equals(s:from(2, 4, '<U>'), [1, 4])
  call s:assert.equals(s:from(2, 6, '<U>'), [1, 5])
  " two empty cells in a row
  call TableopsTestBuffer(['|a|||b|'])
  call s:assert.equals(s:from(1, 2, '<R>'), [1, 4])
  call s:assert.equals(s:from(1, 4, '<R>'), [1, 5])
  call s:assert.equals(s:from(1, 5, '<R>'), [1, 6])
  call s:assert.equals(s:from(1, 6, '<L>'), [1, 5])
  call s:assert.equals(s:from(1, 5, '<L>'), [1, 4])
  " the text objects of the empty cell
  call TableopsTestBuffer(['|a||b|'])
  let @" = 'keep'
  call s:from(1, 4, 'y<I>')
  call s:assert.equals(@", 'keep')
  call s:from(1, 4, 'y<A>')
  call s:assert.equals(@", '|')
endfunction

" ---- o mode never takes the separator row ------------------------------------

function! s:suite.operator_up_and_down_do_not_cross_the_separator() abort
  for [l:lnum, l:keys] in [[2, 'd<D>'], [2, 'd3<D>'], [4, 'd<U>'], [6, 'd3<U>'],
        \ [2, 'y<D>'], [4, 'c<U>zz']]
    call TableopsTestBuffer(s:T)
    let @" = 'keep'
    call s:from(l:lnum, 3, l:keys)
    call s:assert.equals(TableopsTestLines(), s:T, l:lnum . l:keys)
    call s:assert.equals(@", 'keep', l:lnum . l:keys)
  endfor
  " below the separator it works
  call TableopsTestBuffer(s:T)
  call s:from(6, 3, 'd2<U>')
  call s:assert.equals(TableopsTestLines(), s:T[0 : 2] + s:T[6 :])
endfunction

" ---- text objects on the separator row (E3) -----------------------------------

function! s:suite.text_objects_on_the_separator_row_are_cancelled() abort
  " typed (not repeated with .): no object, c does not start Insert mode
  " (zz would be typed in Insert mode)
  for l:col in [2, 8, 13]
    for l:keys in ['c<I>zz', 'c<A>zz', 'd<I>', 'd<A>', 'y<I>']
      call TableopsTestBuffer(s:T)
      let @" = 'keep'
      call s:from(3, l:col, l:keys)
      call s:assert.equals(TableopsTestLines(), s:T, l:col . l:keys)
      call s:assert.equals(@", 'keep', l:col . l:keys)
    endfor
  endfor
endfunction
