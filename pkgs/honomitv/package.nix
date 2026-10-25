args@{
  callPackage,
  fetchFromGitHub,
  python314,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  pythonInterpreter ? python314,
  ...
}:
callPackage ./build.nix (
  builtins.removeAttrs args [ "fetchFromGitHub" ]
  // {
    inherit
      pyproject-nix
      uv2nix
      pyproject-build-systems
      pythonInterpreter
      ;
    pname = "honomitv";
    generateLogos = true;
    version = "0.14.1-unstable-2026-10-25";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "79aef79dd21f9b27b0123728b11bbe3c2bb88572";
      hash = "sha256-CN5UxJnrUY1kwqFi5heSvkEA2seWP2lzpuD4zhyomPw=";
    };
    yarnHash = "sha256-jqg/e6NB5HLi7idxxfJL5T5oRrm720zYTzQ8EXb/QpQ=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
