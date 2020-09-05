" Returns the background color of the given highlight group, as a two-element
" array containing the cterm and the gui entry.
fun! colortemplate#syn#hi_group_bg(hl)
  return [synIDattr(synIDtrans(hlID(a:hl)), "bg", "cterm"), synIDattr(synIDtrans(hlID(a:hl)), "bg", "gui")]
endf

" Ditto, for the foreground color.
fun! colortemplate#syn#hi_group_fg(hl)
  return [synIDattr(synIDtrans(hlID(a:hl)), "fg", "cterm"), synIDattr(synIDtrans(hlID(a:hl)), "fg", "gui")]
endf

fun! colortemplate#syn#attributes(synid, mode)
  let l:attrs = []
  for l:a in ['bold', 'italic', 'inverse', 'standout', 'underline', 'undercurl']
    if '1' ==# synIDattr(a:synid, l:a, a:mode)
      call add(l:attrs, l:a)
    endif
  endfor
  if '1' ==# synIDattr(a:synid, 'strike', a:mode)
    call add(l:attrs, 'strikethrough')
  endif
  return l:attrs
endf

fun! s:toggle_attribute(synid, attr)
  " Note that in terminals, Vim (correctly) always uses cterm attributes, even
  " when termguicolors is set (termguicolors is only about colors, not
  " attributes). NeoVim does not get it right, IMO (and Bram's), because it
  " uses gui attributes when termguicolors is set.
  let l:mode = (has('gui_running') || (has('neovim') && &termguicolors)) ? 'gui' : 'cterm'
  let l:synid = synIDtrans(a:synid)
  let l:old_attrs = colortemplate#syn#attributes(l:synid, l:mode)
  let l:name = synIDattr(l:synid, 'name')
  if empty(l:name) || l:name == 'Normal'
    echohl WarningMsg
    unsilent echo '[Colortemplate] Attributes cannot be set for Normal.'
    echohl None
    return
  endif
  let l:i = index(l:old_attrs, a:attr)
  if l:i == -1
    execute 'hi' l:name l:mode..'='..a:attr..','..join(l:old_attrs, ',')
    echo '[Colortemplate] Set ' .. a:attr .. ' in ' .. l:name
  else
    call remove(l:old_attrs, l:i)
    execute 'hi' l:name l:mode..'='..(empty(l:old_attrs) ? 'NONE' : join(l:old_attrs, ','))
    echo '[Colortemplate] Removed ' .. a:attr .. ' from ' .. l:name
  endif
endf

fun! colortemplate#syn#toggle_attribute(synid, attr)
  call s:toggle_attribute(a:synid, a:attr)
endf

" Prints information about the highlight group at the cursor position.
" See: http://vim.wikia.com/wiki/VimTip99 and hilinks.vim script.
fun! colortemplate#syn#hi_group()
  let trans = synIDattr(synID(line("."), col("."), 0), "name")
  let synid = synID(line("."), col("."), 1)
  let higrp = synIDattr(synid, "name")
  let synid = synIDtrans(synid)
  let logrp = synIDattr(synid, "name")
  let fgcol = [synIDattr(synid, "fg", "cterm"), synIDattr(synid, "fg", "gui")]
  let bgcol = [synIDattr(synid, "bg", "cterm"), synIDattr(synid, "bg", "gui")]
  try " The following may raise an error, e.g., if CtrlP is opened while this is active
    execute "hi!" "ColortemplateInfoFg" "ctermbg=".(empty(fgcol[0])?"NONE":fgcol[0]) "guibg=".(empty(fgcol[1])?"NONE":fgcol[1])
    execute "hi!" "ColortemplateInfoBg" "ctermbg=".(empty(bgcol[0])?"NONE":bgcol[0]) "guibg=".(empty(bgcol[1])?"NONE":bgcol[1])
  catch /^Vim\%((\a\+)\)\=:E254/ " Cannot allocate color
    hi clear ColortemplateInfoFg
    hi clear ColortemplateInfoBg
  endtry
  echo join(map(reverse(synstack(line("."), col("."))), {i,v -> synIDattr(v, "name")}), " ⊂ ")
  execute "echohl" logrp | echon " xxx " | echohl None
  echon (higrp != trans ? "T:".trans." → ".higrp : higrp) . (higrp != logrp ? " → ".logrp : "")." "
  echohl ColortemplateInfoFg | echon "  " | echohl None
  echon " fg=".join(fgcol, "/")." "
  echohl ColortemplateInfoBg | echon "  " | echohl None
  echon " bg=".join(bgcol, "/")
endf

fun! colortemplate#syn#toggle()
  if exists("#colortemplate_syn_info")
    autocmd! colortemplate_syn_info
    augroup! colortemplate_syn_info
  else
    augroup colortemplate_syn_info
      autocmd CursorMoved * call colortemplate#syn#hi_group()
    augroup END
  endif
endf

" Configurable values for the 16 terminal ANSI colors
" These are arbitrary hex values for terminal colors in the range 0-15. These
" are defined for situations in which a hex value must be returned under all
" circumstances, even if it is an approximate one.
let g:colortemplate#syn#ansi_colors = [
      \ '#000000',
      \ '#ff0000',
      \ '#00ff00',
      \ '#ffff00',
      \ '#0000ff',
      \ '#ff00ff',
      \ '#00ffff',
      \ '#ffffff',
      \ '#000000',
      \ '#ff0000',
      \ '#00ff00',
      \ '#ffff00',
      \ '#0000ff',
      \ '#ff00ff',
      \ '#00ffff',
      \ '#ffffff',
      \ ]

" Try (hard) to derive a more or less reasonable hex value for a given
" highlight group color. This is trivial if the environment supports millions
" of colors and the highlight group defines guifg/guibg/guisp; it is easy if
" the cterm color is a number >15 (see above). But the highlight group may not
" define guifg/guibg/guisp, the environment may support only 256 colors, and
" the terminal color might be a number in [0-15], a name (e.g., Magenta), or
" fg/bg (or it may not exist either).
"
" This function is useful, for instance, when importing highlight group
" definitions to create a template, or in the style popup. In such cases,
" getting an approximate value is better than nothing.
"
" name: the name of a highlight group
" type: 'fg', 'bg', or 'sp'
fun! colortemplate#syn#higroup2hex(name, type)
  if has('gui_running') || (has('termguicolors') && &termguicolors)
    let l:gui = synIDattr(synIDtrans(hlID(a:name)), a:type.'#', 'gui')
    if empty(l:gui)
      if a:type ==# 'sp'
        return colortemplate#syn#higroup2hex(a:name, 'fg')
      elseif a:name == 'Normal'
        return a:type ==# 'bg' ? '#ffffff' : '#000000'
      endif
      return colortemplate#syn#higroup2hex('Normal', a:type)
    endif
    return l:gui
  endif
  " Assume 256-color terminal
  let l:term = synIDattr(hlID(a:name), a:type, 'cterm')
    if empty(l:term)
      if a:type ==# 'sp'
        return colortemplate#syn#higroup2hex(a:name, 'fg')
      elseif a:name == 'Normal'
        return a:type ==# 'bg' ? '#ffffff' : '#000000'
      endif
      return colortemplate#syn#higroup2hex('Normal', a:type)
    endif
    " If we get here, then l:term is non-empty, but it might not be a number
    if l:term !~ '\m^\d\+$'
      if l:term =~# '\m^[fb]g$'
        if a:name == 'Normal' " ? Should never happen
          return (l:term ==# 'bg' ? '#ffffff' : '#000000')
        endif
        return colortemplate#syn#higroup2hex('Normal', l:term)
      endif
      try " to convert name to number
        let l:term = string(colortemplate#colorspace#ctermcolor(tolower(l:term), 16))
      catch " What?!
        return a:type ==# 'bg' ? '#ffffff' : '#000000'
      endtry
    endif
    " If we get here, we've got a color number in [0-255]
    try " to get corresponding hex value
      let l:gui = colortemplate#colorspace#xterm256_hexvalue(str2nr(l:term))
      return l:gui
    catch " Term number is in [0,15]
      return g:colortemplate#syn#ansi_colors[str2nr(l:term)]
    endtry
  endif
endf

" vim: foldmethod=marker nowrap et ts=2 sw=2
