" operatorfunc entries for the dot-repeatable <Plug> mappings. Each opfunc
" reads v:count when it runs (F4): 0 is the cursor column and N column N,
" for the first run and for . alike (and 2. gives 2). Nothing is stored.

let s:save_cpo = &cpoptions
set cpoptions&vim

" From nnoremap <expr>: set the opfunc and return g@l.
function! tableops#op#prepare(name) abort
  let &operatorfunc = 'tableops#op#' . a:name
  return 'g@l'
endfunction

function! tableops#op#delete_column(type) abort
  call tableops#delete_column_count(v:count)
endfunction

function! tableops#op#insert_after(type) abort
  call tableops#insert_column_count(v:count, 0)
endfunction

function! tableops#op#insert_before(type) abort
  call tableops#insert_column_count(v:count, 1)
endfunction

" Moving takes the count as a distance.
function! tableops#op#move_left(type) abort
  call tableops#move_column(string(-v:count1))
endfunction

function! tableops#op#move_right(type) abort
  call tableops#move_column(string(v:count1))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
