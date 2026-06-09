# 配布は nix flake とし、TCC 権限は責任プロセス帰属に依存する

calpeek は Swift + EventKit のコンパイル済みバイナリを nix flake で配布する。nix は `/nix/store` のパスもバイナリのハッシュもリビルドごとに変わるため、「TCC のカレンダー権限がバイナリの署名・ハッシュに紐づくなら、更新のたびに再許可が必要になるのでは」という問題があった。これは macOS の TCC が CLI のカレンダーアクセスを呼び出し元の**責任プロセス**(ターミナルアプリや sketchybar 等のステータスバープロセス)に帰属させる挙動に依存して回避する。calpeek 自体への署名は行わない。

## Consequences

- ステータスバー / ターミナル経由で起動する限り、nix でリビルド・更新しても権限は失われない(権限はターミナルアプリ等に付いているため)。
- **launchd や cron から calpeek を直接起動する構成は避ける。** その場合責任プロセスが calpeek 自身になり、store パスが変わるたびに再許可が必要になる。
- macOS 14+ の `requestFullAccessToEvents` は、プロセスの Info.plist に `NSCalendarsFullAccessUsageDescription` がないとクラッシュする。CLI には bundle がないため、リンカフラグ `-sectcreate __TEXT __info_plist` で Info.plist をバイナリに埋め込む。これは消してよいものではない。
- nixpkgs の Swift ツールチェーンは本家より古いことがあるため、言語機能は Swift 5.9 程度に抑える。

## Considered Options

- **SwiftPM + make install + 自己署名証明書**: 署名を安定させれば権限がバイナリ自身に紐づいても持続する。nix での宣言的管理を優先して不採用。
- **Homebrew tap**: 他者配布まで視野に入る場合の選択肢。現時点では個人利用のため過剰。
