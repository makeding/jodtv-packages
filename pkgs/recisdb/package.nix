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
  recisdbDvb =
    (v4l-utils.override {
      withGUI = false;
      withBPF = false;
    });
in
rustPlatform.buildRustPackage {
  pname = "recisdb";
  version = "1.3.2-unstable-2026-11-10";
  src = fetchFromGitHub {
    owner = "makeding";
    repo = "recisdb-rs";
    rev = "88c325c7a23f897088b0eb71b536e56b9d6ed2b7";
    hash = "sha256-L1MV/n3Zs4pHFiagmoOqbXELoSDu2qtTctc394eZGMI=";
  };
  cargoHash = "sha256-IFa9E7OxNX+1p6bRNUGwVQIwXIBwTnd4qhma4TCOIYA=";
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
