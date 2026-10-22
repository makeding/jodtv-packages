{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  pcsclite,
  libaribb25,
}:
rustPlatform.buildRustPackage {
  pname = "recisdb";
  version = "1.3.0";
  src = fetchFromGitHub {
    owner = "kazuki0824";
    repo = "recisdb-rs";
    rev = "2d41c30f55e1af834fe0a33717274e5a3625a0ff";
    hash = "sha256-NGVZX1VWGhZHkFfR0aK9fw71c2Zk/EkkPtdTW8Gzltw=";
  };
  cargoHash = "sha256-8UAs1N44+3dVSdgHGGVl32+KMMVrur1j06yMpxxQz2s=";
  buildNoDefaultFeatures = true;
  buildFeatures = [ "bg-runtime" ];
  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];
  buildInputs = [
    pcsclite
    libaribb25
  ];

  # Require the caller's B25 library. Never build the bundled copy on probe failure.
  postPatch = ''
    cat > b25-sys/build.rs <<'EOF'
    fn main() {
        pkg_config::Config::new().probe("libpcsclite").expect("external PC/SC is required");
        pkg_config::Config::new().probe("libaribb25").expect("external libaribb25 is required");
    }
    EOF
  '';
  meta = {
    description = "ISDB character-device recorder with an injectable B25 decoder";
    homepage = "https://github.com/kazuki0824/recisdb-rs";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "recisdb";
    maintainers = [ lib.maintainers.huggy ];
  };
}
