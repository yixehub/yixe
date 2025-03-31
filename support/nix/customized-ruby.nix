{ pkgs
, ruby
, buildEnv
, stdenv
, makeBinaryWrapper
}:

let
  ruby-packages = import (pkgs.path + "/pkgs/top-level/ruby-packages.nix");
  inherit (ruby) buildGems;

  gems = buildGems (ruby-packages // {
    minitest-cc = {
      dependencies = ["rexml"];
      groups = ["default"];
      platforms = [];
      source = {
        remotes = ["https://rubygems.org"];
        sha256 = "sha256-hOMZr83fuLSOD1nESLVBQ8kRbfOphLQ6ojJAe5yr9XI=";
        type = "gem";
      };
      version = "1.0.0";
    };
  });
  
  withPackages = selector:
    let
      selected = selector gems;

      gemEnv = buildEnv {
        name = "ruby-gems";
        paths = selected;
        pathsToLink = [ "/lib" "/bin" "/nix-support" ];
      };

      wrappedRuby = stdenv.mkDerivation {
        name = "wrapped-${ruby.name}";
        nativeBuildInputs = [ makeBinaryWrapper ];
        buildCommand = ''
            mkdir -p $out/bin
            for i in ${ruby}/bin/*; do
              makeWrapper "$i" $out/bin/$(basename "$i") --set GEM_PATH ${gemEnv}/${ruby.gemPath}
            done
        '';
      };
    in stdenv.mkDerivation {
      name = "${ruby.name}-with-packages";
      nativeBuildInputs = [ makeBinaryWrapper ];
      buildInputs = [ selected ruby ];

      dontUnpack = true;

      installPhase = ''
        for i in ${ruby}/bin/* ${gemEnv}/bin/*; do
          rm -f $out/bin/$(basename "$i")
          makeWrapper "$i" $out/bin/$(basename "$i") --set GEM_PATH ${gemEnv}/${ruby.gemPath}
        done
        ln -s ${ruby}/nix-support $out/nix-support
      '';

      passthru = {
        inherit wrappedRuby;
        gems = selected;
      };
    }
  ;
in
  (withPackages (gems: [ gems.minitest gems.minitest-cc ]))
