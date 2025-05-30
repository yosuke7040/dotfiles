# ========= Finder の設定 =========
# Desktopのファイルを表示
defaults write com.apple.finder CreateDesktop -boolean true
# Finderでステータスバーの表示
defaults write com.apple.finder ShowStatusBar -boolean true
# Finderで下にPathの表示
defaults write com.apple.finder ShowPathbar -boolean true
# 拡張子を変更するときの警告無視
defaults write com.apple.finder FXEnableExtensionChangeWarning -boolean false
# Finderで隠しファイルも表示する
defaults write com.apple.finder AppleShowAllFiles -string true
defaults write NSGlobalDomain AppleShowAllExtensions -boolean true
# # Finderの初期フォルダをhomeに設定
# defaults write com.apple.finder NewWindowTarget -string "PfDe"
# defaults write com.apple.finder NewWindowTargetPath "file://${HOME}/"
killall Finder

# # ========= Dock の設定 =========
# # Dockのサイズ変更
# defaults write com.apple.dock tilesize -int 20
# # Dockにアクティブなアプリケーションのみ表示
# defaults write com.apple.dock static-only -bool true
# # Dockを自動非表示
# defaults write com.apple.dock autohide -boolean true
# # Dockのアイコンにカーソルを合わせた時に拡大・サイズ指定
# defaults write com.apple.dock magnification -boolean true
# defaults write com.apple.dock largesize -int 70
# killall Dock

# # ========= TrackPad の設定 =========
# # TrackPadで３本指で移動
# defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -int 1
# defaults write com.apple.AppleMultitouchTrackpad Clicking -int 1
# # TrackPadでタッチでクリック設定
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -int 1
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 2
# defaults write com.apple.driver.AppleMultitouchTrackpad Clicking -int 1
# defaults write com.apple.driver.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 2
# defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# # TrackPadの移動速度指定
# defaults write NSGlobalDomain com.apple.trackpad.scaling -float 7

# ========= その他 =========
# ダウンロードしたアプリを開いたときの警告無視
defaults write com.apple.LaunchServices LSQuarantine -boolean false
# スクリーンを解除する時にパスワードの要求
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
# バッテリーを%表示
defaults write com.apple.menuextra.battery ShowPercent -string YES
# ダッシュボードの無効化
defaults write com.apple.dashboard mcx-disabled -boolean true
# 自動で大文字化する機能無効化
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -boolean false
# スペルチェック無効化
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -boolean false
# メニューバーの日付表示形式指定
defaults write com.apple.menuextra.clock DateFormat -string "yyyy年 MM月dd日(E) a hh時mm分ss秒"
# ファイルの保存画面の変更
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -boolean true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -boolean true
# # スクリーンショットの保存先を変更
# defaults write com.apple.screencapture location ~/Desktop
# # スクリーンショットで日付を入れない
defaults write com.apple.screencapture include-date -int 0
# MissionControlでデスクトップの順番が入れ替わるの禁止
defaults write com.apple.dock mru-spaces -boolean false
# ライブ変換無効化
defaults write com.apple.inputmethod.Kotoeri JIMPrefLiveConversionKey -boolean false
#
defaults write -g NSWindowShouldDragOnGesture -bool true

killall SystemUIServer

# スクショの保存先がどこになっているか分からなくなって、デフォに戻したくなった時
# defaults delete com.apple.screencapture
