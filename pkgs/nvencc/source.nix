{
  lib,
  cudaPackages_12_9,
  symlinkJoin,
  meson,
  ninja,
  pkg-config,
  gnugrep,
  makeWrapper,
  addDriverRunpath,
  ffmpeg,
  libass,
  libdovi,
  hdr10plus,
  avisynthplus,
  vapoursynth,
  version,
  src,
}:
let
  cuda = cudaPackages_12_9;
  toolkit = symlinkJoin {
    name = "nvencc-cuda-${cuda.cuda_nvcc.version}";
    paths = lib.unique (lib.concatMap
      (p: map (output: lib.getOutput output p) [ "bin" "include" "lib" "static" "stubs" ])
      [ cuda.cuda_nvcc cuda.cuda_cudart cuda.libnpp cuda.cuda_nvrtc cuda.cccl ]);
    postBuild = ''
      ln -s lib "$out/lib64"
      mkdir -p "$out/targets/x86_64-linux"
      ln -s ../../lib "$out/targets/x86_64-linux/lib"
    '';
  };
in
cuda.backendStdenv.mkDerivation {
  pname = "nvencc";
  inherit version src;
  nativeBuildInputs = [ meson ninja pkg-config gnugrep makeWrapper cuda.cuda_nvcc ];
  buildInputs = [ ffmpeg libass libdovi hdr10plus avisynthplus vapoursynth
    cuda.cuda_cudart cuda.libnpp cuda.cuda_nvrtc cuda.cccl ];
  env.CUDA_PATH = toolkit;
  env.CUDACXX = "${cuda.cuda_nvcc}/bin/nvcc";
  mesonFlags = [
    "-Dnvenc_cuda_dir=${toolkit}"
    "-Denable_libplacebo=disabled"
    "-Denable_vmaf=disabled"
    "-Denable_libvship=disabled"
    "-Denable_vulkan=disabled"
    "-Denable_onnxruntime=disabled"
  ];
  postFixup = ''
    # Link using build-time CUDA stubs, load the consuming host's real driver.
    IFS=: read -ra entries <<< "$(patchelf --print-rpath "$out/bin/nvencc")"
    runtime="${lib.makeLibraryPath [ cuda.cuda_cudart cuda.libnpp ]}:${addDriverRunpath.driverLink}/lib"
    for entry in "''${entries[@]}"; do
      case "$entry" in
        ${toolkit}/*) ;;
        *) runtime="$runtime:$entry" ;;
      esac
    done
    patchelf --set-rpath "$runtime" "$out/bin/nvencc"
    wrapProgram "$out/bin/nvencc" --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libass cuda.cuda_nvrtc ]}:${addDriverRunpath.driverLink}/lib
  '';
  passthru = { inherit ffmpeg toolkit; fromSource = true; };
  meta = {
    description = "NVENC encoder built against the selected FFmpeg libraries";
    homepage = "https://github.com/rigaya/NVEnc";
    license = [ lib.licenses.mit lib.licenses.nvidiaCudaRedist ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "nvencc";
    maintainers = [ lib.maintainers.huggy ];
  };
}
