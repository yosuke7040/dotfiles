# dotfiles

以下の感じでdotfileの実態をリポジトリにおいて、読み取りディレクトリにはシンボリックリンクを配置
```zsh
ln -s "$HOME/src/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
ln -s "$HOME/src/dotfiles/git/.gitconfig" "$HOME/.gitconfig"
ln -s "$HOME/src/dotfiles/starship/starship.toml" "$HOME/.config/starship.toml"
ln -s "$HOME/src/dotfiles/wezterm" "$HOME/.config/wezterm"
ln -s "$HOME/src/dotfiles/nvim" "$HOME/.config/nvim"
```

この管理だと、ファイル修正後にsourceで何故か反映されないのでログインしなおすこと