# 環境変数
export LANG=ja_JP.UTF-8

setopt +o nomatch

# ヒストリの設定
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# --> alias
source $HOME/.aliases

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libpq/include"
export CR_PAT="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"

# direnv
export EDITOR=vim
eval "$(direnv hook zsh)"

# glob表現
setopt nomatch

# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# nodebrew
export PATH=$HOME/.nodebrew/current/bin:$PATH

# kubelogin
# export KUBECONFIG=/Users/abe/.kube/config

# express
export PATH=/usr/local/share/npm/bin:$PATH
export NODE_PATH=/usr/local/lib/node_modules

# goのパスとバージョン管理
# # export PATH="$PATH:$(go env GOPATH)/bin"
# # ↓2つは~/.zshenvに書き込む
# eval "$(goenv init -)"
# export GOENV_ROOT="$HOME/.goenv"
# export PATH="$GOENV_ROOT/bin:$PATH"
# export GOENV_ROOT="$HOME/.goenv"
# export PATH="$GOENV_ROOT/bin:$PATH"
# eval "$(goenv init -)"
# export PATH="$GOROOT/bin:$PATH"
# export PATH="$PATH:$GOPATH/bin"

# starship
eval "$(starship init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# 補完候補を詰めて表示
setopt list_packed
# 補完候補一覧をカラー表示
autoload colors
zstyle ':completion:*' list-colors ''
# ビープ音を鳴らさない
setopt no_beep
# ディレクトリスタック
DIRSTACKSIZE=100
setopt AUTO_PUSHD
## historyコマンドをヒストリリストから取り除く。
setopt hist_no_store
## すぐにヒストリファイルに追記する。
setopt inc_append_history
## ヒストリを呼び出してから実行する間に一旦編集
setopt hist_verify
## コマンドラインの先頭がスペースで始まる場合ヒストリに追加しない
setopt hist_ignore_space
# 他のターミナルとヒストリーを共有
setopt share_history
## zsh の開始, 終了時刻をヒストリファイルに書き込む
setopt extended_history
## The following lines were added by compinstall
zstyle :compinstall filename '~/.zshrc'
## 補完候補を一覧表示
setopt auto_list
## TAB で順に補完候補を切り替える
setopt auto_menu
## 補完候補一覧でファイルの種別をマーク表示
setopt list_types
## カッコの対応などを自動的に補完
setopt auto_param_keys
## ディレクトリ名の補完で末尾の / を自動的に付加し、次の補完に備える
setopt auto_param_slash
## 補完候補のカーソル選択を有効に
zstyle ':completion:*:default' menu select=1
## 補完候補の色づけ
export ZLS_COLORS=$LS_COLORS
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
## スペルチェック
setopt correct
## ファイル名の展開でディレクトリにマッチした場合末尾に / を付加する
setopt mark_dirs
## 最後のスラッシュを自動的に削除しない
setopt noautoremoveslash
## コアダンプサイズを制限
limit coredumpsize 102400
## 出力の文字列末尾に改行コードが無い場合でも表示
unsetopt promptcr
## ビープを鳴らさない
setopt nobeep
## 内部コマンド jobs の出力をデフォルトで jobs -l にする
setopt long_list_jobs
## サスペンド中のプロセスと同じコマンド名を実行した場合はリジューム
setopt auto_resume
## 同じディレクトリを pushd しない
setopt pushd_ignore_dups
## ファイル名で #, ~, ^ の 3 文字を正規表現として扱う
setopt extended_glob
## =command を command のパス名に展開する
setopt equals
## --prefix=/usr などの = 以降も補完
setopt magic_equal_subst
## ファイル名の展開で辞書順ではなく数値的にソート
setopt numeric_glob_sort
## 出力時8ビットを通す
setopt print_eight_bit
## ドットなしでもドットファイルにマッチ
setopt globdots
## {a-c} を a b c に展開する機能を使えるようにする
setopt brace_ccl

autoload -Uz colors
colors
zstyle ':completion:*' list-colors "${LS_COLORS}"

CURRENT_DIR="%{${fg[blue]}%}[%~]%{${reset_color}%}"

autoload -Uz vcs_info
setopt PROMPT_SUBST
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "%F{yellow}!"
zstyle ':vcs_info:git:*' unstagedstr "%F{red}+"
zstyle ':vcs_info:*' formats "%F{green}%c%u[%b]%f"
zstyle ':vcs_info:*' actionformats '[%b|%a]'

# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ../ の後は今いるディレクトリを補完しない
zstyle ':completion:*' ignore-parents parent pwd ..

# sudo の後ろでコマンド名を補完する
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin \
                   /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin

# ps コマンドのプロセス名補完
zstyle ':completion:*:processes' command 'ps x -o pid,s,args'

# wezterm
export PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"

# fabric-samples
# itn用に作った(https://hyperledger-fabric.readthedocs.io/en/release-2.2/install.html)
export PATH="$PATH:/Users/abe/src/job/itn/fabric-samples/bin"

# ghqとの連携。ghqの管理化にあるリポジトリを一覧表示する。ctrl - ]にバインド。
function peco-src () {
  local selected_dir=$(ghq list -p | peco --prompt="repositories >" --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

# # commandの履歴検索。ctrl - rにバインド
# function select-history() {
#   BUFFER=$(history -n -r 1 | fzf --no-sort +m --query "$LBUFFER" --prompt="History > ")
#   CURSOR=$#BUFFER
# }
# zle -N select-history
# bindkey '^r' select-history
# setopt hist_expire_dups_first # 履歴を切り詰める際に、重複する最も古いイベントから消す
# setopt hist_ignore_all_dups   # 履歴が重複した場合に古い履歴を削除する
# setopt hist_ignore_dups       # 前回のイベントと重複する場合、履歴に保存しない
# setopt hist_save_no_dups      # 履歴ファイルに書き出す際、新しいコマンドと重複する古いコマンドは切り捨てる

function select-git-branch() {
  target_br=$(
    git branch -a |
      fzf --exit-0 --layout=reverse --info=hidden --no-multi --preview-window="right,65%" --prompt="CHECKOUT BRANCH > " --preview="echo {} | tr -d ' *' | xargs git lg --color=always" |
      head -n 1 |
      perl -pe "s/\s//g; s/\*//g; s/remotes\/origin\///g"
  )
  if [ -n "$target_br" ]; then
    BUFFER+="$target_br"
    zle redisplay
    # BUFFER="git switch $target_br"
    # zle accept-line
  fi
}
zle -N select-git-branch
bindkey "^g" select-git-branch # 「control + G」で実行

eval "$(rbenv init - zsh)"

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# if type brew &>/dev/null; then
#   FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  autoload -Uz compinit
  compinit
# fi
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# zsh-completions入れた時に実行する
# chmod go-w '/opt/homebrew/share'
# chmod -R go-w '/opt/homebrew/share/zsh'

## カレントディレクトリ以下のディレクトリ検索・移動
function find_cd() {
  local selected_dir=$(find . -type d | peco)
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
}
zle -N find_cd
bindkey '^X' find_cd

# # git logをpecoで選択してコミットハッシュを入力
# # git restore まで入力してcontrol + iでコミットハッシュを選択して入力
# function peco-git-log() {
#     local selected_commit=$(git log --oneline -n 20 | peco | awk '{print $1}')
#     if [ -n "$selected_commit" ]; then
#       BUFFER+="$selected_commit"
#       CURSOR=$#BUFFER
#       zle redisplay
#     fi
#     zle clear-screen
# }
# zle -N peco-git-log
# bindkey '^i' peco-git-log  ^iがTabと同じキーコードらしく不便

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

# シンタックスハイライト
zinit ice wait'0'; zinit light zsh-users/zsh-syntax-highlighting
# 入力補完
zinit ice wait lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
# zinit ice wait'0'; zinit light zsh-users/zsh-autosuggestions
zinit ice wait'0'; zinit light zsh-users/zsh-completions

eval "$(zoxide init zsh)"
# 矢印キーが上の挙動は下のほうが好みなので無効化
eval "$(atuin init zsh --disable-up-arrow)"

# pythonバージョン管理
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nodeバージョン管理
export PATH="$HOME/.nodenv/bin:$PATH"
eval "$(nodenv init - --no-rehash)"
export PATH="$HOME/.nodenv/versions/20.0.0/bin:$PATH"

export GOPRIVATE=github.com/handy-inc

# asdf
# 最後に持ってきた方が良い。brewでインストールしたパスより先にasdfのパス見てくれる
# 整理をめんどくさがるな！！
export PATH="$HOME/.asdf/shims:$PATH"


# aws-mfaがpip3ではなく、pipを参照している？っぽいのでそのためのパス
export PATH="/Users/abe/Library/Python/3.9/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql@8.0/bin:$PATH"

# sqnoflake使うなら
alias snowsql=/Applications/SnowSQL.app/Contents/MacOS/snowsql

# mise
# インストール方法：curl https://mise.run | sh
# echo "eval \"\$(/Users/abe/.local/bin/mise activate zsh)\"" >> "/Users/abe/.zshrc"
eval "$(/Users/abe/.local/bin/mise activate zsh)"
# ❯ go env GOPATH
# /Users/abe/.local/share/mise/installs/go/1.23.3/bin
# export GOPATH="$HOME/.local/share/mise/installs/go/1.23.3/bin"
export GOPATH="$HOME/go"
# ❯ go env GOROOT
# /Users/abe/.local/share/mise/installs/go/1.23.3
export GOROOT="$HOME/.local/share/mise/installs/go/1.23.3"
export PATH="$GOROOT/bin:$PATH"
# export PATH="$PATH:$GOPATH/bin"
