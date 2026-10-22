# jodtv-packages

**日本語** | [English](README.en.md)

日本のデジタルテレビ放送向けパッケージと、再利用可能な NixOS モジュールです。

## NixOS flake から使う

```nix
inputs.jodtv-packages = {
  url = "github:makeding/jodtv-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

必要なモジュールをインポートします。

```nix
imports = [
  inputs.jodtv-packages.nixosModules.packages
  inputs.jodtv-packages.nixosModules.dtv
];
dtv.tuners = [ { driver = "pt3"; } ];
dtv.hirakud.enable = true;
```

`packages` モジュールはパッケージの overlay を追加します。個別のサービスモジュールは
パッケージセットを利用側に委ねるため、既存の overlay やローカル override の適用順を
維持できます。モジュールをインポートするだけではサービスは有効になりません。
モジュールを使わずパッケージだけ利用する場合は、
`inputs.jodtv-packages.overlays.default` を `nixpkgs.overlays` に追加してください。
`nixosModules.default` は overlay とすべてのサービスモジュールをまとめて読み込みます。
各サービスは初期状態では無効です。
Mirakurun は nixpkgs の NixOS モジュールを利用し、EPGStation はそのモジュールを
拡張して外部 EPG 更新プロセスに対応しています。

チューナーモジュールは利用先の `boot.kernelPackages` に合わせてドライバーをビルドします。
カーネル、チャンネル一覧、ネットワーク、ストレージ、ホスト固有のモジュールパラメーターは
選択しません。PT3 の簡略指定には既定のデバイス番号があり、PX4 にはドライバーに
同梱されたファームウェアが追加されます。それ以外に必要なファームウェアや機器固有の
設定は利用側で用意してください。
PT3、上流版 PX4、Siano、TBS6812 のドライバーを含みます。実験的な PX4 PC/SC
プラグインはパッケージ化しておらず、外付けカードリーダーは別パッケージです。
カーネルドライバーの derivation はモジュール内部で扱い、別のカーネル向けに
ビルドしたバイナリを公開パッケージとして提供することはありません。

`packages.x86_64-linux` はすべてのパッケージを公開します。`aarch64-linux` では
ARM 向けのパッケージングを検証するまで、HonomiTV/KonomiTV と Intel 向け
エンコード関連パッケージを除外しています。`aarch64-darwin` では Hiraku、libaribb61、libaribtlv、
PSI/SI ツール、tsreadex、tsreplace、FFmpeg パッチセットを公開します。
ソースの取得を伴うパッケージが無関係なツールの評価まで要求しないよう、公開する一覧を
明示しています。出力が存在することは、そのプラットフォームでビルド済みであることを
意味しません。HonomiTV と FFmpeg パッチセットの評価にはソースが必要です。
`--option allow-import-from-derivation false` を指定すると、その要求を確認できます。

## 利用側で依存パッケージを差し替える

録画ツールは通常の `libaribb25` をパッケージ引数として受け取ります。
このリポジトリを変更せず、利用側のパッケージに差し替えられます。

```nix
final: prev: {
  recpt1 = prev.recpt1.override { libaribb25 = final.myAribLibrary; };
  recisdb = prev.recisdb.override { libaribb25 = final.myAribLibrary; };
  recdvb = prev.recdvb.override { libaribb25 = final.myAribLibrary; };
}
```

利用側の overlay は jodtv-packages の overlay より後に適用してください。
ほかのアプリケーションは通常の依存パッケージを引き続き使います。
認証情報、非公開の派生実装、デプロイ設定は利用側のリポジトリで管理し、
このリポジトリから参照しないでください。

## 検証

```sh
nix build --no-link .#checks.x86_64-linux.dependency-injection \
  .#checks.x86_64-linux.dtv
nix build --no-link .#recisdb .#recpt1 .#recdvb
```

checks では録画ツールの依存パッケージの差し替えと NixOS モジュールの組み合わせを
検証し、チューナードライバーが利用先のカーネルに対応することも確認します。
評価の検証、Linux パッケージの実ビルド、サービスの動作確認、実機での受信確認は
それぞれ別の検証です。

パッケージのバージョンとパッチは、デプロイ用リポジトリの履歴を取り込まずに移しました。
各ソフトウェアには引き続き上流のライセンスが適用されます。このリポジトリから、
同梱するすべてのソフトウェアに共通のライセンスが適用されると解釈しないでください。
一部の固定バージョンではライセンスの許諾が示されておらず、unfree として扱っています。
利用する場合は、利用側の nixpkgs 設定で明示的に許可してください。
Git リポジトリが公開されていることだけでは、利用許諾にはなりません。

## 共通の DTV 設定

`nixosModules.default` で overlay とモジュールをまとめて読み込むか、
`nixosModules.packages` と `nixosModules.dtv` を個別に読み込みます。
`dtv.tuners` と `dtv.channels` を一度定義すれば、モジュールが Mirakurun の設定を生成し、
各チューナーに必要なツールとローカルドライバーを追加します。

ローカルチューナーの `driver` は `pt3`、`px4`、`siano`、`tbs6812`、汎用の `dvb` です。
`mode = []` はドライバーだけを登録する指定です。受信用の項目には放送方式とデバイスを
指定し、必要に応じて名前を付けます。`command` ではコマンドを引数のリストで指定できます。
`hiraku` はリモートの Hiraku エージェント、`remote` はリモートの Mirakurun に接続します。
リモートの受信元を指定しても、ローカルのドライバーやエージェントは有効になりません。
各項目では `enable`、追加の `packages`、Mirakurun 固有の `settings` を設定できます。
ローカル受信では `b25`、`b61`、`strip`、`args`、`argsBS4K` などを指定できます。
`dtv.packages` で録画ツール、Hiraku、変換ツールを差し替えられ、利用側の overlay も反映されます。

ローカルチューナーを Hiraku 経由で公開するには `dtv.hirakud.enable` を有効にします。
ローカル項目は既定で公開対象になり、`serve.enable = false` で個別に除外できます。
`serve.mode` と `serve.modeBS4K` で公開するモード名を指定します。
チューナーの定義だけで Hirakud や Mirakurun が起動することはありません。

Mirakurun の `listen` では `port`、`unixSocket`、`ipv6` を指定できます。
EPGStation の `listen` では HTTP と Socket.IO のポートを指定できます。
これらのモジュールでは任意の待ち受けアドレスを指定するオプションは提供していません。
Hiraku の `listen` はアプリケーション本来の `address:port` 形式です。
サービス固有の設定、認証情報、ストレージ、データベースのオプションは、
引き続き各 NixOS サービスモジュールで設定できます。

簡略指定の `{ driver = "pt3"; }` は、GR 2 系統と BS/CS 2 系統の
`PT3-T1/T2/S1/S2` に展開されます。2 枚目以降は T3/T4/S3/S4 と連番になり、
デバイス番号のオフセットも自動で増えます。`name` と `deviceOffset` で既定値を
変更できます。`mode` を明示した場合は展開せず、単一のチューナーとして扱います。
`mode = []` はハードウェアの登録のみを行います。PT3 以外では `mode` の明示が必要です。

マシン間で設定を再利用する場合は、`A.config.dtv.exports.hirakuTuners` を
`lib.mkHirakuTuners { tuners = ...; address = ...; secret = ...; }` に渡します。
リモート Mirakurun を使う場合は `A.config.dtv.exports.mirakurunTuners` を
`lib.mkRemoteTuners` に渡し、`host` を指定します。
`A.config.dtv.exports.channels` は利用側の `dtv.channels` に設定します。
公開するチューナー情報にはデバイスパスや認証情報は含まれません。

カードリーダーは任意で利用でき、録画ツールのデコード設定とは独立しています。
`dtv.card.enable = true` で PC/SC、CCID、pcsc-tools を有効にします。
`dtv.card.rw5100Support = true` を追加すると、RW5100 プラグインと USB のアクセス権を設定します。
`dtv.card.plugins` には追加のプラグインを指定できます。既存のパッケージ overlay も反映されます。

## 設定例

三点セットと分離構成は [samples](samples/README.md) を参照してください。

## HonomiTV の設定

`services.honomitv.settings` と `encoder` は、`config.yaml` が存在しない場合だけ
初期設定を書き込みます。HonomiTV で保存した変更は、再起動や NixOS の rebuild 後も
保持されます。初回起動後はアプリケーション側で設定を編集してください。
ファイアウォール、ディレクトリーへのアクセス、サービス間の依存関係は引き続き
Nix で管理するため、アプリ側でポートや保存先を変える際は Nix 側も合わせてください。

## recisdb への移行

PT3/PX4/TBS6812 は recisdb 1.3.0（`83e8068`）を使用します。`dtv.packages.recpt1` は
`dtv.packages.recisdb` に変更してください。`args` は recisdb の構文
（例: `--lnb 15v`）に更新してください。明示的な `command` は自動変換しません。
Mirakurun/Hirakud 共通のアダプターが地上波の数値チャンネルに `T` を付け、
BS/CS/C 形式はそのまま渡します。`b25 = false` は `--no-decode`、
`strip = false` は `--no-strip` になります。TBS6812 の BS/CS/BS4K も recisdb を使います。
数値 device は `/dev/dvb/adapterN/frontend0` に変換し、BS4K は `--b61` と
`argsBS4K`（`--cas-proxy` など）を渡します。他の DVB ドライバーは従来どおりです。

外部 `libaribb25` と `libaribb61` を必須とし、内蔵ライブラリへのフォールバックはありません。
差し替え先には SIMD を含む上流 B25 ABI が必要です。既定 feature を無効化し、
`bg-runtime`、`b61` と Linux の `dvb` を有効にします。
`recisdb.override { libaribb61 = myB61Library; }` で B61 を独立して差し替えられます。
`decode --b61` と実験的な DVB ISDB-S3 選局に対応します。デコーダーの既定値は変更しません。
独自のカードリーダー優先機能（`--card`）は使えません。

DIY 用に `recpt1` の独立パッケージと overlay 属性を引き続き公開します。
外部 `libaribb25` の差し替えも可能です。チューナーで使う場合は
`dtv.tuners[].command` に recpt1 の引数を明示し、その項目の `packages` に
`pkgs.recpt1` を追加してください。PT3/PX4 の既定コマンドは recisdb です。

## libaribb61

Linux/macOS 向けの独立した MMT/TLV ACAS デスクランブルライブラリです。
パッケージ一覧と overlay で公開し、`nix build .#libaribb61` でビルドできます。
ヘッダー `aribb61/arib_std_b61.h`、共有ライブラリ、pkg-config 用の
`libaribb61.pc` をインストールします。C API は B25 に似ていますが ABI 互換ではありません。
`recdvb4k` の `--b61` はこの共有ライブラリを使用し、ビルド時に B25/B61 の両方を必須にします。
利用側で `recdvb4k.override { libaribb61 = myB61Library; }` により差し替えられます。
通常の `recdvb` は独立した B25 専用ビルドです。上流の core/C API テストと
インストール済みライブラリへの C API リンクを検証します。カード/プロキシや
実放送のデスクランブルは別途実機での検証が必要です。

TBS6812 の各物理チューナーは GR と BS/CS/BS4K を排他的に設定します。
GR と衛星モードの混在は評価時に拒否します。2 つのチューナーは個別に選択できます。
