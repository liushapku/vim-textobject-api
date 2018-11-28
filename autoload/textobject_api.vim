" textobject-api - Define your own textobject using a function returning
" position
"
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Interface  "{{{1

let s:motion_wiseness = {'v': 'char', 'V': 'line', "\<c-v>": 'block'}
let s:visual_mode = { 'char':'v', 'line': 'V', 'block': "\<c-v>"}
function! s:set_pos(callback)
  let info = function(a:callback)()
  let motion_wiseness = get(info, 'motion_wiseness', mode())
  let mode = get(s:visual_mode, motion_wiseness, 'v')
  let extend = get(info, 'extend', '')
  if type(info) != v:t_dict
    return "\<esc>"
  endif
  try
    if extend == ''
    elseif motion_wiseness == 'line'
      call textobject_api#extend('line', extend, info)
    elseif motion_wiseness == 'char'
      call textobject_api#extend('char', extend, info)
    endif
    call setpos("'<", [0, info.begin[0], info.begin[1], 0])
    call setpos("'>", [0, info.end[0], info.end[1], 0])
    return mode
  catch
    throw v:throwpoint . ':' . v:exception
  endtry
endfunction
function! textobject_api#vmap(callback)
  let mode =  s:set_pos(a:callback)
  return "gv" . (mode == visualmode()? '':mode)
endfunction
function! textobject_api#omap(callback)
  let vmap = textobject_api#vmap(a:callback)
  return printf(":normal! %s\<cr>", vmap)
endfunction

function! textobject_api#extend_forward(motion_wiseness, end)
  call cursor(a:end)
  if a:motion_wiseness == 'line'
    let to = search('^.*\S', 'W')
    let to = to? to-1: line('$')
    return [to, a:end[1]]
  else
    let line = getline('.')
    let nline = len(line)
    let idx = match(line, '\S', a:end[1])
    let idx = idx==-1? nline: idx
    return [a:end[0], idx]
  endif
endfunction
function! textobject_api#extend_backward(motion_wiseness, begin)
  call cursor(a:begin)
  if a:motion_wiseness == 'line'
    let from = search('^.*\S', 'bW')
    let from = from? from+1: 1
    return [from, a:begin[1]]
  else
    let line = join(reverse(split(getline('.'), '\zs')), '')
    let nline = len(line)
    let idx = match(line, '\S', nline - a:begin[1] + 1)
    let idx = idx==-1? 1: nline - idx + 1
    return [a:begin[0], idx]
  endif
endfunction
function! s:direction(direction)
  let idx = match(['bidrection', 'forward', 'backward', 'forward_first', 'backward_first'], a:direction)
  if idx == -1
    throw 'unknown direction'
  elseif idx == 0
    return [1, 1, 0]
  else
    let forward = a:direction =~ '^forward'
    let backward = a:direction =~ '^backward'
    let other = a:direction =~ '_first$'
    return [forward, backward, other]
  endif
endfunction
function! textobject_api#extend(motion_wiseness, direction, info)
  let [forward, backward, other] = s:direction(a:direction)
  if forward
    let end = textobject_api#extend_forward(a:motion_wiseness, a:info.end)
    if end != a:info.end
      let other = 0
    endif
    let a:info.end = end
  endif
  if backward || other
    let begin = textobject_api#extend_backward(a:motion_wiseness, a:info.begin)
    if begin != a:info.begin
      let other = 0
    endif
    let a:info.begin = begin
  endif
  if other && !forward
    let a:info.end = textobject_api#extend_forward(a:motion_wiseness, a:info.end)
  endif
endfunction


" func: funcref or string for function name
" optional: a dictionary containing the following keys
" 1. nmap: whether define nmap ]mapstr to move to the last position and
" [mapstr to move to the begin position. default 1
" 2. visual: can be '' or 'V' or "\<c-v>", used to overwrite the visual mode
" 3. extend: whether extend the region to include the empty lines following or
" (only relavant in "move")
" 4. count: the way to handle count in moving. 'repeat' using for loop. 'callback'
" handled by callback. 'asis': do not modify the count, propagate to the expr.
" otherwise remove the count from the expr in "move")
" 5. options: other map options such as '<buffer> <silent>'
function! textobject_api#define(mapstr, callback, ...) abort
  let options = get(a:000, 0, {})
  let nmap = get(options, 'nmap', 0)
  let count = get(options, 'count', '')
  let mapopts = get(options, 'options', '')
  exe printf("vnoremap %s <expr> %s textobject_api#vmap(%s)", mapopts, a:mapstr, string(a:callback))
  exe printf("onoremap %s <expr> %s textobject_api#omap(%s)", mapopts, a:mapstr, string(a:callback))
  if nmap
    call textobject#define_move(a:mapstr, a:func, extend, count, options, visual)
  endif
endfunction

function! textobject_api#test()
  2Log mode(1) visualmode() nvim_get_mode()
  let rv = {}
  let l1 = get(g:, 'l1', 140)
  let l2 = get(g:, 'l2', 143)
  let c1 = get(g:, 'c1', 3)
  let c2 = get(g:, 'c2', 4)
  "let rv.motion_wiseness = 'line'
  let rv.begin = [l1, c1]
  let rv.end = [l2, c2]
  let rv.extend = 'forward_first'
  return rv
endfunction
call textobject_api#define('S', 'textobject_api#test')
" vim: foldmethod=marker


" __END__  "{{{1
