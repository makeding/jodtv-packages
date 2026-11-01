{
  self,
  nixpkgs,
  pkgs,
}:
{
  amatsukaze-package =
    assert self.packages.x86_64-linux.amatsukaze.meta.mainProgram == "AmatsukazeCLI";
    assert self.packages.aarch64-linux.amatsukaze.meta.mainProgram == "AmatsukazeCLI";
    assert self.packages.aarch64-linux.amatsukaze.doCheck;
    assert self.packages.aarch64-linux.amatsukaze.doInstallCheck;
    assert !(self.packages.x86_64-linux ? amatsukaze-native);
    assert !(self.packages.aarch64-linux ? amatsukaze-native);
    assert !(self.packages.aarch64-darwin ? amatsukaze);
    assert !(self.nixosModules ? amatsukaze);
    assert !(self.legacyPackages.x86_64-linux.amatsukaze ? sourceBuild);
    pkgs.runCommand "amatsukaze-package" { } "touch $out";
}
