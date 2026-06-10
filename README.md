# calpeek

Mac のカレンダーを覗き、ステータスバー(tmux・sketchybar 等)に埋め込める一行の予定表示を出力する CLI。

```
▶ 全社会 〜15:00 (残25m) → 14:50 1on1 (in 15m)
```

## 表示ルール

- **進行中の予定 (now)** があればそれを表示。複数重なっていれば最も遅く始まったもの
- now がなければ**当日の次の予定 (next)** を表示
- now があり、かつ next の開始まで **30 分以内**なら `now → next` の 2 件表示
- 終日イベントと自分が辞退したイベントは無視
- 当日中に何もなければ `予定がありません` と出力する(exit 0)

用語の正確な定義は [CONTEXT.md](./CONTEXT.md) を参照。

## 使い方

```console
$ calpeek
10:30 プロダクト朝会 (in 1h51m)

$ calpeek --calendars "仕事,個人"   # 対象カレンダーを名前で絞り込み
$ calpeek --threshold 15           # 2件表示のしきい値を15分に変更(既定30)
```

## インストール

```console
$ nix profile install github:luvpame/calpeek
```

ローカル開発:

```console
$ swift build && ./.build/debug/calpeek
$ nix build   # flake でのビルド検証
```

## 初回セットアップ(カレンダー権限)

カレンダー権限は calpeek 自体ではなく**起動元のアプリ**(ターミナルや sketchybar)に付与されます。

1. ステータスバーに組み込む前に、使うアプリのシェルから一度 `calpeek` を手動実行する
2. 表示される許可ダイアログで「フルアクセスを許可」を選ぶ
3. 以後は nix で calpeek を更新しても再許可は不要

権限がない状態では stdout に `⚠ calpeek: カレンダー権限なし` と出ます(exit 1)。
ダイアログを逃した場合は システム設定 > プライバシーとセキュリティ > カレンダー から起動元アプリに手動で許可してください。

> **注意**: launchd や cron から calpeek を直接起動する構成は避けてください。権限の帰属が calpeek 自身になり、nix 更新のたびに再許可が必要になります。詳細は [docs/adr/0001](./docs/adr/0001-nix-flake-distribution-and-tcc.md)。

## ステータスバーへの組み込み例

tmux:

```tmux
set -g status-interval 30
set -g status-right "#(calpeek) | %H:%M"
```

sketchybar:

```bash
sketchybar --add item calpeek right \
           --set calpeek update_freq=30 script="sketchybar --set calpeek label=\"$(calpeek)\""
```
