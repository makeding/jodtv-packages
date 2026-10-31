{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libaribb61,
  v4l-utils,
  libaribb25,
}:
let
  # This dependency is private to recisdb's ISDB-S IF interface.
  recisdbDvb =
    (v4l-utils.override {
      withGUI = false;
      withBPF = false;
    }).overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [ ./libdvbv5-isdbs-if.patch ];
      });
in
rustPlatform.buildRustPackage {
  pname = "recisdb";
  version = "1.3.0-unstable-2026-10-31";
  src = fetchFromGitHub {
    owner = "makeding";
    repo = "recisdb-rs";
    rev = "301ff3eeddf12229bd46b4549fea7a30ab4873da";
    hash = "sha256-26O1mu4E12wau7uiBYTghsFMNb7gg3Q3sOZk4cYMUeA=";
  };
  cargoHash = "sha256-pMBiqzAJ/Dqg3AnUV8O7D1ItQo/sBSXerlocpcop3Vg=";
  buildNoDefaultFeatures = true;
  buildFeatures = [
    "bg-runtime"
    "b61"
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux "dvb";
  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];
  buildInputs = [
    libaribb25
    libaribb61
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    recisdbDvb
  ];

  postPatch = ''
    cat > b25-sys/build.rs <<'EOF'
    fn main() {
        pkg_config::Config::new().probe("libaribb25").expect("external libaribb25 is required");
    }
    EOF
    cat > b61-sys/build.rs <<'EOF'
    fn main() {
        pkg_config::Config::new().atleast_version("0.1.0")
            .probe("libaribb61").expect("external libaribb61 is required");
    }
    EOF
  '';
  passthru.libdvbv5 = recisdbDvb;
  meta = {
    description = "ISDB recorder with injectable B25/B61 decoders and Linux DVB support";
    homepage = "https://github.com/makeding/recisdb-rs";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "recisdb";
    maintainers = [ lib.maintainers.huggy ];
  };
}
