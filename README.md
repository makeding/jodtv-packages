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
拡張してデータベースのパスワード初期化と外部 EPG 更新プロセスに対応しています。
ローカルの Mirakurun を設定済みなら、`dtv.epgstation.enable = true;` で有効にできます。
パスワードは初回の activation 時に生成されます。明示した `database.passwordFile` と
既存のデータ・認証情報は維持されます。

チューナーモジュールは利用先の `boot.kernelPackages` に合わせてドライバーをビルドします。
カーネル、チャンネル一覧、ネットワーク、ストレージ、ホスト固有のモジュールパラメーターは
選択しません。PT3 の簡略指定には既定のデバイス番号があり、PX4 にはドライバーに
同梱されたファームウェアが追加されます。それ以外に必要なファームウェアや機器固有の
設定は利用側で用意してください。
PT3、上流版 PX4、Siano、TBS6812、A865R のドライバーを含みます。実験的な PX4 PC/SC
プラグインはパッケージ化しておらず、外付けカードリーダーは別パッケージです。
カーネルドライバーの derivation はモジュール内部で扱い、別のカーネル向けに
ビルドしたバイナリを公開パッケージとして提供することはありません。

`packages.x86_64-linux` はすべてのパッケージを公開します。`aarch64-linux` では
以下のアーキテクチャ固有の 5 パッケージを除外しています。`aarch64-darwin` では Hiraku、libaribb61、libaribtlv、
PSI/SI ツール、mmt2ts、tsreadex、tsreplace、FFmpeg パッチセットを公開します。
ソースの取得を伴うパッケージが無関係なツールの評価まで要求しないよう、公開する一覧を
明示しています。出力が存在することは、そのプラットフォームでビルド済みであることを
意味しません。HonomiTV と FFmpeg パッチセットの評価にはソースが必要です。
`--option allow-import-from-derivation false` を指定すると、その要求を確認できます。

CI は Linux の両出力を同一リビジョンで、ネイティブ runner
（`ubuntu-24.04` / `ubuntu-24.04-arm`）上でビルドします。各アーキテクチャで
共有 derivation のビルドとアップロードを完了してから個別パッケージをビルドします。
手動指定は各出力との共通部分を対象とし、未知の名前はエラーにします。
キャッシュ GC は両方が成功した後に実行し、現在と前回の保持対象リビジョンについて
両アーキテクチャの依存関係と出力を保護します。

ARM Linux の HonomiTV/KonomiTV は FFmpeg を使い、同梱 QSVEncC/NVEncC は対象外です。
除外する 5 パッケージは `amatsukaze`（x64 バンドル・エンジン）、`edcb-wine`
（Windows x64/Wine）、`intel-media-sdk-h` と `qsvencc`（Intel 向け）、
`nvencc`（amd64 バンドル・x86 CUDA 設定）です。
CI のビルド成功はチューナー、カードリーダー、GPU の実機動作を保証しません。

## MMT/TLV 変換ツール

`nix build .#mmt2ts` で `mmt2ts`、`ts2mmt`、`mmtcut` をまとめてビルドできます。
MMT/TLV と MPEG-2 TS の相互変換、解析・検証、時間範囲による切り出しに対応します。
Linux と macOS 向けの独立パッケージです。利用例と検証範囲は
[パッケージ仕様](pkgs/mmt2ts/README.md)を参照してください。

Mirakurun の BS4K 変換は設定で切り替えられます。

```nix
dtv.mmtsConverter = "mmt2ts"; # または "dantto4k"（既定値）
```

BS4K の非 remote チューナーで選択したツールだけを使用します。
`dtv.tuners[].mmtsDecoder = false` で変換を無効にできます。
パッケージの差し替えには `dtv.packages.mmt2ts` / `dtv.packages.dantto4k` を使います。

## バイナリキャッシュ

[jodtv.cachix.org](https://jodtv.cachix.org) のビルド済みパッケージを利用するには、
NixOS の設定に追加してください。

```nix
nix.settings = {
  extra-substituters = [ "https://jodtv.cachix.org" ];
  extra-trusted-public-keys = [
    "jodtv.cachix.org-1:aYGvlIzrrtKlHUyKX+FP/hsgELT8SeaPnMeAn2tQDG4="
  ];
};
```

既存のキャッシュ設定は維持されます。同じ derivation がキャッシュにある場合に
利用され、利用側の nixpkgs や override が異なる場合はローカルビルドになることがあります。

## 利用側で依存パッケージを差し替える

録画ツールは通常の `libaribb25` をパッケージ引数として受け取ります。
このリポジトリを変更せず、利用側のパッケージに差し替えられます。

```nix
final: prev: {
  recisdb = prev.recisdb.override { libaribb25 = final.myAribLibrary; };
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
nix build --no-link .#recisdb
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

ローカルチューナーの `driver` は `a865r`、`pt3`、`px4`、`siano`、`tbs6812`、汎用の `dvb` です。
`mode = []` はドライバーだけを登録する指定です。受信用の項目には放送方式とデバイスを
指定し、必要に応じて名前を付けます。`command` ではコマンドを引数のリストで指定できます。
`hiraku` はリモートの Hiraku エージェント、`remote` はリモートの Mirakurun に接続します。
リモートの受信元を指定しても、ローカルのドライバーやエージェントは有効になりません。
各項目では `enable`、追加の `packages`、Mirakurun 固有の `settings` を設定できます。
ローカル受信では `b25`、`b61`、`lnb`、`strip`、`args`、`argsBS4K` などを指定できます。
`lnb = true` は BS/CS/BS4K のローカル受信で 15V 給電を要求します（`--lnb 15v`）。既定値は `false`（電圧未指定）です。GR 専用チューナーと明示的な command 指定には適用しません。
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

## A865R

A865R は標準 DVB frontend として登録され、recisdb で録画します。Nix が固定ハッシュの
Windows インストーラーを Release から取得し、AVer857BDA.sys だけを展開・検証します。
インストーラーは実行しません。unfree の `a865r-firmware` を許可してください。
`dtv.a865r.firmware` で別の SYS / FW を指定できます。バイナリはソース管理に含めません。

```nix
dtv.mirakurun.enable = true;
dtv.tuners = [{
  driver = "a865r";
  mode = [ "GR" ];
  device = "/dev/dvb/adapter0/frontend0";
}];
```

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

CAS プロキシは `services.casproxyserver.enable = true` で有効にできます。
A の `settings.listenIp`、`settings.port`、`settings.allowedIps` を設定し、
必要に応じて `openFirewall = true` でポートを開放します。
B は次の参照だけでローカル BS4K/B61 録画に利用できます。

```nix
# B (Colmena)
{ nodes, ... }: {
  dtv.casProxy = nodes.A.config.dtv.exports.casProxy;
}
```

Mirakurun/Hirakud の recisdb コマンドに `--cas-proxy` が追加されます。
チューナー単位の `casProxy = null` でローカルカードに戻せます。
A が `0.0.0.0` で待ち受ける場合は `services.casproxyserver.advertiseAddress` に
B から到達できるアドレスを指定してください。A の許可ネットワークとファイアウォールは
A で管理します。詳細は [サービス管理](docs/service-ownership.md) を参照してください。

EPGStation の MariaDB 起動・DB 作成・パスワード設定は既存の NixOS モジュールが
管理します。利用側で同じ DB の `initialDatabases` / `ensureUsers` を重複定義する
必要はありません。既存データやパスワードを移行する変更ではありません。

三点セットと分離構成は [samples](samples/README.md) を参照してください。

## 原版パッケージの選択

既定の HonomiTV と EPGStation fork はそのまま利用できます。原版は
`pkgs.konomitv`（tsukumijima/KonomiTV）と `pkgs.epgstation-upstream`
（l3tnun/EPGStation）を明示的に選択してください。
`pkgs.epgstation` は引き続き `pkgs.epgstation-h` を指します。

```nix
{ pkgs, ... }: {
  services.honomitv.package = pkgs.konomitv;
  dtv.epgstation.package = pkgs.epgstation-upstream;
  # dtv を使わない場合:
  # services.epgstation.package = pkgs.epgstation-upstream;
}
```

既存のサービスモジュールと設定方法を使います。KonomiTV は独立した上流ソースと
Python 3.13 / uv lock を利用します。Nix のパス・書き込み先・直接 HTTP 待ち受けの
調整だけを共通化し、fork の機能パッチは取り込みません。TLS は利用側で終端します。
原版 EPGStation では fork 固有の `epgUpdaterMode = "external"` は使えません。
パッケージ指定だけではデータベースや設定の相互移行は行いません。

## HonomiTV の設定

`services.honomitv.settings` と `encoder` は、`config.yaml` が存在しない場合だけ
初期設定を書き込みます。HonomiTV で保存した変更は、再起動や NixOS の rebuild 後も
保持されます。初回起動後はアプリケーション側で設定を編集してください。
ファイアウォール、ディレクトリーへのアクセス、サービス間の依存関係は引き続き
Nix で管理するため、アプリ側でポートや保存先を変える際は Nix 側も合わせてください。

## recisdb の録画仕様

すべてのローカルチューナー（PT3/PX4/A865R/TBS6812/Siano/DVB）は
`dtv.packages.recisdb` を使います。公開する録画パッケージは recisdb に統一し、
公開していないパッケージ属性・設定オプションの選択は Nix 評価エラーになります。
`args` と `argsBS4K` は recisdb の構文を使います。明示的な `command` は自動変換しません。
Mirakurun/Hirakud 共通のアダプターが地上波の数値チャンネルに `T` を付け、
BS/CS/C 形式はそのまま渡します。`b25 = false` は `--no-decode`、
`strip = false` は `--no-strip` になります。DVB の数値 device は
`/dev/dvb/adapterN/frontend0` に変換し、デバイスパスはそのまま渡します。
BS4K は `--b61` と `argsBS4K`（`--cas-proxy` など）を渡します。

外部 `libaribb25` と `libaribb61` を必須とし、内蔵ライブラリへのフォールバックはありません。
差し替え先には SIMD を含む上流 B25 ABI が必要です。既定 feature を無効化し、
`bg-runtime`、`b61` と Linux の `dvb` を有効にします。
`recisdb.override { libaribb61 = myB61Library; }` で B61 を独立して差し替えられます。
`decode --b61` と実験的な DVB ISDB-S3 選局に対応します。デコーダーの既定値は変更しません。
独自のカードリーダー優先機能（`--card`）は使えません。

## libaribb61

Linux/macOS 向けの独立した MMT/TLV ACAS デスクランブルライブラリです。
パッケージ一覧と overlay で公開し、`nix build .#libaribb61` でビルドできます。
ヘッダー `aribb61/arib_std_b61.h`、共有ライブラリ、pkg-config 用の
`libaribb61.pc` をインストールします。C API は B25 に似ていますが ABI 互換ではありません。
`recisdb` の `--b61` はこの共有ライブラリを使用します。
利用側で `recisdb.override { libaribb61 = myB61Library; }` により差し替えられます。
上流の core/C API テストと
インストール済みライブラリへの C API リンクを検証します。カード/プロキシや
実放送のデスクランブルは別途実機での検証が必要です。

TBS6812 の各物理チューナーは GR と BS/CS/BS4K を排他的に設定します。
GR と衛星モードの混在は評価時に拒否します。2 つのチューナーは個別に選択できます。

## BS4K のメディア処理

`dtv.bs4k` は `dtv.tuners` と同じ階層です。有効なチューナーの `mode` に
`"BS4K"` があれば自動で有効になります。リモート配信や録画ファイルだけを扱う場合:

```nix
dtv.bs4k = true;
```

FFmpeg/FFprobe、QSVEncC、NVEncC、tsreplace、HonomiTV/KonomiTV（PyAV を含む）、
両 EPGStation と Amatsukaze のメディア処理部を `ffmpeg-libaribtlv` に統一します。
NVEncC と Amatsukaze の対象ツールはソースから再ビルドします。バイナリ内蔵の
FFmpeg は PATH の変更だけでは置き換わりません。BS4K がなければ通常のパッケージを
使用し、有効な BS4K チューナーがある状態で明示的に false にすると評価エラーになります。

パッケージの選択にはホスト側の `pkgs` を使ってください。
例: `services.honomitv.package = pkgs.konomitv`。
別の flake 評価や `nix run .#...` には NixOS の設定は引き継がれません。
ソースビルドには Linux builder、NVEncC には CUDA 再配布ライブラリも必要です。

## Amatsukaze と NVEncC

x86_64 Linux で `amatsukaze` と `nvencc` の unfree パッケージを許可して実行します。

```sh
nix run .#amatsukaze
nix run .#amatsukaze -- add-task -f /recordings/input.ts
nix run .#amatsukaze -- cli --help
nix run .#nvencc -- --help
```

WebUI は既定で `http://localhost:32769/`、状態は
`${XDG_DATA_HOME:-$HOME/.local/share}/amatsukaze` に保存します。
`--state-dir` または `AMATSUKAZE_STATE_DIR` で変更できます。
更新時も設定、プロファイル、キュー、履歴を保持します。AviSynth、フィルターと
ソフトウェアエンコーダーを同梱しています。NVEncC は独立したパッケージで、
Linux の KonomiTV/HonomiTV にも組み込みます。ソフトウェア処理だけの Amatsukaze
には不要です。NVIDIA エンコードにはホスト側の動作する NVIDIA ドライバーが必要です。

default モジュールに含まれる任意のサービス:

```nix
services.amatsukaze = {
  enable = true;
  mediaDirectories = [ "/srv/recordings" "/srv/encoded" ];
  # openFirewall = true; # サーバー 32768、WebUI 32769
};
```

## EDCB on Wine

x86_64 Linux のデスクトップでは、Wine と日本語フォントを含むランチャーで起動できます。

```sh
nix run .#edcb-wine
nix run .#edcb-wine -- scan-gr
nix run .#edcb-wine -- scan-bs
nix run .#edcb-wine -- capture
nix run .#edcb-wine -- --backend-host tuner.example --backend-port 40772
```

X11 / XWayland が必要です。データは `~/.local/share/edcb-wine`
（`XDG_DATA_HOME` 対応）に保存し、`--state-dir` で変更できます。初回に設定・
録画先・専用 Wine prefix を作成し、指定したバックエンドを次回も使用します。
EMWUI は `http://localhost:5510/EMWUI/` です。詳細は `--help` を参照してください。
unfree が未許可の場合は `NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#edcb-wine`
で実行できます。

`nixosModules.edcb-wine`（default モジュールにも同梱）で、x86_64 Linux 上の
EDCB 260921 / BonDriver_mirakc / EMWUI と Xvfb/Openbox デスクトップを利用できます。
パッケージ overlay とモジュールを import した後、次のように有効化します。

```nix
services.edcb-wine = {
  enable = true;
  backend.host = "localhost"; # Mirakurun / mirakc
  backend.port = 40772;
};
```

VNC は `127.0.0.1:5900` に待ち受けます。SSH ポート転送で接続してください。
EMWUI は `http://HOST:5510/EMWUI/` です。`openFirewall = true` で EDCB の
ポートを開放します。バイナリ一式は保守的に unfree として扱うため、利用側の
Nixpkgs ポリシーで `edcb-wine` を許可してください。更新時も INI・チャンネル・
予約・履歴を保持します。保存先や検証範囲は
[パッケージ仕様](docs/edcb-wine-packaging.md)を参照してください。
