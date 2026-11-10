scriptencoding utf-8

let s:suite = themis#suite('command_columns')
let s:assert = themis#helper('assert')

let s:T = [
      \ 'intro',
      \ '| name | 年齢 | city \| area |',
      \ '|:-----|-----:|:------------:|',
      \ '| foo  |   12 | tokyo        |',
      \ 'outro']

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  messages clear
endfunction

function! s:suite.columns_of_the_header() abort
  call cursor(4, 1)
  let l:tick = changenr()
  call s:assert.equals(execute('TableopsColumns'), "\n1:name  2:年齢  3:city \\| area")
  call s:assert.equals(TableopsTestLines(), s:T)
  call s:assert.equals(changenr(), l:tick)
  " from the separator row, with the mapping
  call cursor(3, 3)
  call s:assert.equals(execute("normal \<Plug>(tableops-columns)"), "\n1:name  2:年齢  3:city \\| area")
endfunction

function! s:suite.columns_empty_and_missing_header_cells() abort
  call TableopsTestBuffer(['| a |  |', '|---|--|---|', '| 1 | 2 | 3 |'])
  call s:assert.equals(execute('TableopsColumns'), "\n1:a  2:(empty)  3:(empty)")
endfunction

function! s:suite.columns_of_a_headerless_table_are_its_first_row() abort
  call TableopsTestBuffer(['| x | y |', '| 1 | 2 | 3 |'])
  call cursor(2, 1)
  call s:assert.equals(execute('TableopsColumns'), "\n1:x  2:y  3:(empty)")
endfunction

function! s:suite.columns_with_a_range() abort
  call cursor(1, 1)
  call s:assert.equals(execute('3TableopsColumns'), "\n1:name  2:年齢  3:city \\| area")
endfunction

function! s:suite.columns_outside_a_table() abort
  call cursor(1, 1)
  TableopsColumns
  call s:assert.equals(TableopsTestMessage(), '[tableops] not in a table')
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction
