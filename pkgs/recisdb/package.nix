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
rustPlatform.buildRustPackage {
  pname = "recisdb";
  version = "1.3.0-unstable-2026-10-22";
  src = fetchFromGitHub {
    owner = "makeding";
    repo = "recisdb-rs";
    rev = "83e8068eae3db0c4f62cde080870a03323e56db6";
    hash = "sha256-N8mgDbsYvcXssiurW9nlNgscbVRf4GdXvpg7/ZJiilA=";
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
    (v4l-utils.override {
      withGUI = false;
      withBPF = false;
    })
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
  meta = {
    description = "ISDB recorder with injectable B25/B61 decoders and Linux DVB support";
    homepage = "https://github.com/makeding/recisdb-rs";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "recisdb";
    maintainers = [ lib.maintainers.huggy ];
  };
}
