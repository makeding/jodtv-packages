# 設定例

**日本語** | [English](README.en.md)

既存の NixOS flake に追加するモジュール例です。OS のインストール設定ではありません。
`samples` ディレクトリごと利用側へコピーし、通常のハードウェア設定と併せて読み込んでください。

| ファイル | 用途 |
| --- | --- |
| [all-in-one.nix](all-in-one.nix) | PT3 1 枚で Mirakurun・EPGStation・HonomiTV を同じマシンで動かす |
| [hirakud.nix](hirakud.nix) | PT3 の 4 系統を Hiraku 経由で公開するチューナー側 |
| [remote.nix](remote.nix) | Hiraku の 4 系統を受けて Mirakurun に渡すフロントエンド側 |
| [channels.json](channels.json) | 全例で共有するチャンネル一覧。地域に合わせて変更する |

## 三点セットを読み込む

```nix
inputs.jodtv-packages = {
  url = "github:makeding/jodtv-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};

# Inside nixpkgs.lib.nixosSystem:
modules = [
  inputs.jodtv-packages.nixosModules.default
  ./hardware-configuration.nix
  ./samples/all-in-one.nix
];
```

`all-in-one.nix` は x86_64-linux 向けです。Mirakurun は標準ポート 40772、
EPGStation は 20772（Socket.IO は 20773）、HonomiTV は 7000 を使います。
EPGStation と HonomiTV のファイアウォールを開くため、信頼できるネットワークで使用してください。
HonomiTV は CPU エンコードの FFmpeg を使い、Mirakurun のライブ映像と
EPGStation の録画フォルダーを参照します。HonomiTV のバックエンドを Mirakurun にした場合、
録画予約は EPGStation 側で行います。

HonomiTV の設定は初回のみ書き込み、アプリ側の変更を保持します。
詳しくは [HonomiTV の設定](../README.md#honomitv-の設定) を参照してください。

適用前に次を用意してください。

- `channels.json` を実際に受信できる地域・チャンネルに変更する。
- `/run/secrets/epgstation-db-password` にデータベースのパスワードを配置する。
  sops-nix や agenix などで実行時に配置し、平文を Nix ソースに埋め込まない。
  NixOS モジュールが MariaDB と EPGStation のデータベースを設定する。
- 録画先 `/var/lib/epgstation/recorded` の空き容量を確保する。
  別ディスクを使う場合は、このパスへのマウントや bind mount を利用側で設定する。

CCID カードリーダーを有効にしています。RW5100 を使う場合はコメントの
`card.rw5100Support = true` を有効にし、パッケージの unfree 許可を設定してください。
カードリーダーを使わない構成では `dtv.card.enable = false` に変更できます。

## チューナー側とフロントエンド側を分ける

別々のマシンで `all-in-one.nix` の代わりに `hirakud.nix` と `remote.nix` を読み込みます。
`hirakud.nix` は 40773 を開き、Mirakurun を起動せず PT3 の 4 系統だけを公開します。
`remote.nix` にはローカルドライバーやカードリーダーを追加しません。
両側の共有トークンを同じ値に変更し、`tuner.example:40773` をチューナーマシンのアドレスへ
置き換えてください。トークンは生成される Nix 設定に含まれます。

同じ flake で複数マシンを管理する場合は、`dtv.exports.hirakuTuners` と
`lib.mkHirakuTuners` を使い、受信側にチューナー一覧を重複して書かずに済みます。
詳しくは [共通の DTV 設定](../README.md#共通の-dtv-設定) を参照してください。

これらの例は NixOS 設定の評価で確認します。Linux ビルド、サービスの起動、
実機での受信確認は別途必要です。
