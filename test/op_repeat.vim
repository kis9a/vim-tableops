scriptencoding utf-8

let s:suite = themis#suite('op_repeat')
let s:assert = themis#helper('assert')

" . sees only a change made by :normal in the test function itself (not in
" a helper), so every first run is written out here.

let s:T = [
      \ '| a | b | c | d | e | f |',
      \ '|---|---|---|---|---|---|',
      \ '| 1 | 2 | 3 | 4 | 5 | 6 |',
      \ 'outro']

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  messages clear
endfunction

function! s:header() abort
  return join(tableops#domain#table#split(getline(1)), '')
endfunction

function! s:suite.delete_count_then_dot_dot() abort
  call TableopsTestCursor(3, '1')
  execute "normal 3\<Plug>(tableops-delete-column)"
  call s:assert.equals(s:header(), 'abdef')
  normal .
  call s:assert.equals(s:header(), 'abef')
  call TableopsTestCloseUndo()
  normal .
  call s:assert.equals(s:header(), 'abf')
  call s:assert.equals(TableopsTestLines(), ['| a | b | f |', '|---|---|---|', '| 1 | 2 | 6 |', 'outro'])
  call s:assert.equals([line('.'), TableopsTestChar()], [3, '1'])
  " each one is one undo step
  silent undo
  call s:assert.equals(s:header(), 'abef')
endfunction

function! s:suite.delete_without_count_dot_takes_the_cursor_column() abort
  call TableopsTestCursor(1, 'b')
  execute "normal \<Plug>(tableops-delete-column)"
  call s:assert.equals(s:header(), 'acdef')
  call s:assert.equals(TableopsTestChar(), 'c')
  call TableopsTestCursor(3, '5')
  normal .
  call s:assert.equals(s:header(), 'acdf')
  call s:assert.equals([line('.'), TableopsTestChar()], [3, '6'])
endfunction

function! s:suite.dot_with_a_new_count() abort
  call TableopsTestCursor(3, '6')
  execute "normal 3\<Plug>(tableops-delete-column)"
  call s:assert.equals(s:header(), 'abdef')
  normal 2.
  call s:assert.equals(s:header(), 'adef')
  " . keeps the last count
  normal .
  call s:assert.equals(s:header(), 'aef')
endfunction

function! s:suite.dot_outside_the_table_changes_nothing() abort
  call TableopsTestCursor(3, '1')
  execute "normal \<Plug>(tableops-delete-column)"
  let l:lines = TableopsTestLines()
  call cursor(4, 1)
  normal .
  call s:assert.equals(TableopsTestLines(), l:lines)
  call s:assert.equals(TableopsTestMessage(), '[tableops] not in a table')
endfunction

function! s:suite.insert_dot() abort
  call TableopsTestCursor(3, '6')
  execute "normal 2\<Plug>(tableops-insert-column-after)"
  normal .
  call s:assert.equals(getline(1), '| a | b |   |   | c | d | e | f |')
  call s:assert.equals(TableopsTestChar(), '6')
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(3, '1')
  execute "normal \<Plug>(tableops-insert-column-before)"
  normal .
  call s:assert.equals(getline(1), '|   |   | a | b | c | d | e | f |')
  call s:assert.equals(TableopsTestChar(), '1')
endfunction

function! s:suite.move_dot() abort
  call TableopsTestCursor(3, '1')
  execute "normal \<Plug>(tableops-move-column-right)"
  normal .
  call s:assert.equals(s:header(), 'bcadef')
  call s:assert.equals([line('.'), TableopsTestChar()], [3, '1'])
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(1, 'f')
  execute "normal 2\<Plug>(tableops-move-column-left)"
  call s:assert.equals(s:header(), 'abcfde')
  normal .
  call s:assert.equals(s:header(), 'afbcde')
  call s:assert.equals([line('.'), TableopsTestChar()], [1, 'f'])
  " at the edge: a message, no change
  normal .
  call s:assert.equals(s:header(), 'fabcde')
  normal .
  call s:assert.equals(s:header(), 'fabcde')
  call s:assert.equals(TableopsTestMessage(), '[tableops] column is already at the edge')
endfunction
