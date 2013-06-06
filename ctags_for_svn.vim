" ctags_for_svn.vim - Tells vim where the ctags file is in a SVN repository
" Maintainer:  Daniel Convissor <danielc@analysisandsolutions.com>
" Version:  0.1
"
" Ripped off from https://github.com/tpope/vim-fugitive/
"
" NB:  Use ctags_for_svn.sh to generate the ctags file for the current SVN
" repository.


if exists('g:loaded_ctags_for_svn') || &cp
  finish
endif
let g:loaded_ctags_for_svn = 1

" Utility {{{1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),''))
endfunction

function! s:sub(str,pat,rep) abort
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction

function! s:gsub(str,pat,rep) abort
  return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfunction

function! s:shellesc(arg) abort
  if a:arg =~ '^[A-Za-z0-9_/.-]\+$'
    return a:arg
  elseif &shell =~# 'cmd' && a:arg !~# '"'
    return '"'.a:arg.'"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! s:fnameescape(file) abort
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

function! s:throw(string) abort
  let v:errmsg = 'ctags_for_svn: '.a:string
  throw v:errmsg
endfunction

function! s:warn(str)
  echohl WarningMsg
  echomsg a:str
  echohl None
  let v:warningmsg = a:str
endfunction

function! s:shellslash(path)
  if exists('+shellslash') && !&shellslash
    return s:gsub(a:path,'\\','/')
  else
    return a:path
  endif
endfunction

function! s:recall()
  let rev = s:buffer().rev()
  if rev ==# ':'
    return matchstr(getline('.'),'^#\t\%([[:alpha:] ]\+: *\)\=\zs.\{-\}\ze\%( (new commits)\)\=$\|^\d\{6} \x\{40\} \d\t\zs.*')
  endif
  return rev
endfunction

function! s:add_methods(namespace, method_names) abort
  for name in a:method_names
    let s:{a:namespace}_prototype[name] = s:function('s:'.a:namespace.'_'.name)
  endfor
endfunction

let s:commands = []
function! s:command(definition) abort
  let s:commands += [a:definition]
endfunction

function! s:define_commands()
  for command in s:commands
    exe 'command! -buffer '.command
  endfor
endfunction

augroup ctags_for_svn_utility
  autocmd!
  autocmd User CtagsForSvn call s:define_commands()
augroup END

let s:abstract_prototype = {}

" }}}1
" Initialization {{{1

function! s:ExtractSvnDir(path) abort
  let path = s:shellslash(a:path)
  let fn = fnamemodify(path,':s?[\/]$??')
  let fn = fnamemodify(fn, ':p:h')

  if isdirectory(fn . '/.svn')
    " Present directory contains .svn dir.
    " Is there one in the parent directory too?
    while isdirectory(fn . '/../.svn')
      " Yes, let's try again with its parent.
      let fn = fnamemodify(fn, ':p:h:h')
    endwhile
    return fn . '/.svn'

  else
    " Present directory doesn't contain a .svn dir.
    " So we'll check parent dirs until we reach one with .svn in it or /.
    while !isdirectory(fn . '/.svn')
      " No love yet; let's go to the parent dir.
      let fn = fnamemodify(fn, ':p:h:h')
      if fn == '/'
        " We've reached the root directory.  Stop.
        break
      endif
    endwhile

    if isdirectory(fn . '/.svn')
      return fn . '/.svn'
    else
      return ''
    endif
  endif
endfunction

function! s:Detect(path)
  if exists('b:svn_dir') && (b:svn_dir ==# '' || b:svn_dir =~# '/$')
    unlet b:svn_dir
  endif
  if !exists('b:svn_dir')
    let dir = s:ExtractSvnDir(a:path)
    if dir != ''
      let b:svn_dir = dir
    endif
  endif
  if exists('b:svn_dir')
    silent doautocmd User CtagsForSvn
    cnoremap <expr> <buffer> <C-R><C-G> <SID>recall()
    let buffer = ctags_for_svn#buffer()
    if expand('%:p') =~# '//'
      call buffer.setvar('&path',s:sub(buffer.getvar('&path'),'^\.%(,|$)',''))
    endif
    if stridx(buffer.getvar('&tags'),escape(b:svn_dir.'/tags',', ')) == -1
      call buffer.setvar('&tags',escape(b:svn_dir.'/tags',', ').','.buffer.getvar('&tags'))
      if &filetype != ''
        call buffer.setvar('&tags',escape(b:svn_dir.'/'.&filetype.'.tags',', ').','.buffer.getvar('&tags'))
      endif
    endif
  endif
endfunction

augroup ctags_for_svn
  autocmd!
  autocmd BufNewFile,BufReadPost * call s:Detect(expand('<amatch>:p'))
  autocmd FileType           netrw call s:Detect(expand('<afile>:p'))
  autocmd VimEnter * if expand('<amatch>')==''|call s:Detect(getcwd())|endif
  autocmd BufWinLeave * execute getwinvar(+bufwinnr(+expand('<abuf>')), 'ctags_for_svn_leave')
augroup END

" }}}1
" Repository {{{1

let s:repo_prototype = {}
let s:repos = {}

function! s:repo(...) abort
  let dir = a:0 ? a:1 : (exists('b:svn_dir') && b:svn_dir !=# '' ? b:svn_dir : s:ExtractSvnDir(expand('%:p')))
  if dir !=# ''
    if has_key(s:repos,dir)
      let repo = get(s:repos,dir)
    else
      let repo = {'svn_dir': dir}
      let s:repos[dir] = repo
    endif
    return extend(extend(repo,s:repo_prototype,'keep'),s:abstract_prototype,'keep')
  endif
  call s:throw('not a git repository: '.expand('%:p'))
endfunction

function! ctags_for_svn#repo(...)
  return call('s:repo', a:000)
endfunction

" }}}1
" Buffer {{{1

let s:buffer_prototype = {}

function! s:buffer(...) abort
  let buffer = {'#': bufnr(a:0 ? a:1 : '%')}
  call extend(extend(buffer,s:buffer_prototype,'keep'),s:abstract_prototype,'keep')
  if buffer.getvar('svn_dir') !=# ''
    return buffer
  endif
  call s:throw('not a git repository: '.expand('%:p'))
endfunction

function! ctags_for_svn#buffer(...) abort
  return s:buffer(a:0 ? a:1 : '%')
endfunction

function! s:buffer_getvar(var) dict abort
  return getbufvar(self['#'],a:var)
endfunction

function! s:buffer_setvar(var,value) dict abort
  return setbufvar(self['#'],a:var,a:value)
endfunction

function! s:buffer_getline(lnum) dict abort
  return getbufline(self['#'],a:lnum)[0]
endfunction

function! s:buffer_repo() dict abort
  return s:repo(self.getvar('svn_dir'))
endfunction

function! s:buffer_type(...) dict abort
  if self.getvar('ctags_for_svn_type') != ''
    let type = self.getvar('ctags_for_svn_type')
  elseif fnamemodify(self.spec(),':p') =~# '.\git/refs/\|\.git/\w*HEAD$'
    let type = 'head'
  elseif self.getline(1) =~ '^tree \x\{40\}$' && self.getline(2) == ''
    let type = 'tree'
  elseif self.getline(1) =~ '^\d\{6\} \w\{4\} \x\{40\}\>\t'
    let type = 'tree'
  elseif self.getline(1) =~ '^\d\{6\} \x\{40\}\> \d\t'
    let type = 'index'
  elseif isdirectory(self.spec())
    let type = 'directory'
  elseif self.spec() == ''
    let type = 'null'
  else
    let type = 'file'
  endif
  if a:0
    return !empty(filter(copy(a:000),'v:val ==# type'))
  else
    return type
  endif
endfunction

if has('win32')

  function! s:buffer_spec() dict abort
    let bufname = bufname(self['#'])
    let retval = ''
    for i in split(bufname,'[^:]\zs\\')
      let retval = fnamemodify((retval==''?'':retval.'\').i,':.')
    endfor
    return s:shellslash(fnamemodify(retval,':p'))
  endfunction

else

  function! s:buffer_spec() dict abort
    let bufname = bufname(self['#'])
    return s:shellslash(bufname == '' ? '' : fnamemodify(bufname,':p'))
  endfunction

endif

function! s:buffer_name() dict abort
  return self.spec()
endfunction

function! s:buffer_commit() dict abort
  return matchstr(self.spec(),'^ctags_for_svn://.\{-\}//\zs\w*')
endfunction

function! s:buffer_path(...) dict abort
  let rev = matchstr(self.spec(),'^ctags_for_svn://.\{-\}//\zs.*')
  if rev != ''
    let rev = s:sub(rev,'\w*','')
  elseif self.repo().bare()
    let rev = '/.git'.self.spec()[strlen(self.repo().dir()) : -1]
  else
    let rev = self.spec()[strlen(self.repo().tree()) : -1]
  endif
  return s:sub(s:sub(rev,'.\zs/$',''),'^/',a:0 ? a:1 : '')
endfunction

function! s:buffer_rev() dict abort
  let rev = matchstr(self.spec(),'^ctags_for_svn://.\{-\}//\zs.*')
  if rev =~ '^\x/'
    return ':'.rev[0].':'.rev[2:-1]
  elseif rev =~ '.'
    return s:sub(rev,'/',':')
  elseif self.spec() =~ '\.git/index$'
    return ':'
  elseif self.spec() =~ '\.git/refs/\|\.git/.*HEAD$'
    return self.spec()[strlen(self.repo().dir())+1 : -1]
  else
    return self.path()
  endif
endfunction

function! s:buffer_sha1() dict abort
  if self.spec() =~ '^ctags_for_svn://' || self.spec() =~ '\.git/refs/\|\.git/.*HEAD$'
    return self.repo().rev_parse(self.rev())
  else
    return ''
  endif
endfunction

function! s:buffer_expand(rev) dict abort
  if a:rev =~# '^:[0-3]$'
    let file = a:rev.self.path(':')
  elseif a:rev =~# '^[-:]/$'
    let file = '/'.self.path()
  elseif a:rev =~# '^-'
    let file = 'HEAD^{}'.a:rev[1:-1].self.path(':')
  elseif a:rev =~# '^@{'
    let file = 'HEAD'.a:rev.self.path(':')
  elseif a:rev =~# '^[~^]'
    let commit = s:sub(self.commit(),'^\d=$','HEAD')
    let file = commit.a:rev.self.path(':')
  else
    let file = a:rev
  endif
  return s:sub(s:sub(file,'\%$',self.path()),'\.\@<=/$','')
endfunction

function! s:buffer_containing_commit() dict abort
  if self.commit() =~# '^\d$'
    return ':'
  elseif self.commit() =~# '.'
    return self.commit()
  else
    return 'HEAD'
  endif
endfunction

call s:add_methods('buffer',['getvar','setvar','getline','repo','type','spec','name','commit','path','rev','sha1','expand','containing_commit'])

" vim:set ft=vim ts=8 sw=2 sts=2:
