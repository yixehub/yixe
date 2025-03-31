require "open3"
require "minitest/spec"
require_relative "../../lib/yixe"

module YixeIntegrationTesting
  # Parses a Nix expression with Nix.
  # This way, we can compare the interpretation from Nix,
  # instead of the exact way it was produced.
  def nix_parse(expr)
    Open3.popen2("nix-instantiate", "-", "--parse") do |stdin, stdout, _wait|
      stdin.write(expr)
      stdin.close()
      stdout.read()
    end.strip()
  end

  def yixe_expr(expr)
    Yixe::Document.new(expr, path: "<string>")
  end
end

describe "Integration Testing `yixe-nixos-module`" do
  include YixeIntegrationTesting

  it "trivial module" do
    transpiled =
      yixe_expr(
        <<~EOF,
          yixe-nixos-module: v0

          config:
            networking:
              hostName: yixe-os
        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~EOF,
        {
          config = {
            networking = {
              hostName = "yixe-os";
            };
          };
        }
      EOF
    )
  end

  it "module with arguments" do
    transpiled =
      yixe_expr(
        <<~EOF,
          yixe-nixos-module: v0

          arguments:
           - config
           - ...

          config:
            networking:
              hostName: yixe-os
        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~EOF,
        { config, ... }:
        {
          config = {
            networking = {
              hostName = "yixe-os";
            };
          };
        }
      EOF
    )
  end

  it "usage of arguments" do
    transpiled =
      yixe_expr(
        <<~EOF,
          yixe-nixos-module: v0

          arguments:
           - config
           - ...

          config:
            etc:
              issue:
                text: !arguments.config.networking.hostName
          #{"    "}
        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~EOF,
        { config, ... }:
        {
          config = {
            etc = {
              issue = {
                text = config.networking.hostName;
              };
            };
          };
        }
      EOF
    )
  end

  it "handles JSON-marshalled strings with ${}" do
    transpiled =
      yixe_expr(
        <<~EOF,
          yixe-nixos-module: v0
          config:
            text: "funny string: ${} "
        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~'EOF',
        {
          config.text = "${builtins.fromJSON "\"funny string: \${} \""}";
        }
      EOF
    )
  end

  it "handles JSON-marshalled strings with weird escapes" do
    transpiled =
      yixe_expr(
        <<~'EOF',
          yixe-nixos-module: v0
          config:
            text: "funny escape: \e"
        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~'EOF',
        {
          config.text = "${builtins.fromJSON "\"funny escape: \\u001b\""}";
        }
      EOF
    )
  end
end

# NOTE: those assume a lot about the shape of the outputs!
describe "Integration Testing `yixe-project`" do
  include YixeIntegrationTesting

  it "trivial project" do
    transpiled =
      yixe_expr(
        <<~EOF,
          yixe-project: v0

        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~EOF,
      (let __yixe_top = { }; in __yixe_top)
      EOF
    )
  end

  it "less trivial project" do
    transpiled =
      yixe_expr(
        <<~EOF,
          yixe-project: v0

          inputs:
            sources:
              nixpkgs:
                nixos-channel: nixos-unstable

          outputs:
            hello: !inputs.nixpkgs.hello
        EOF
      ).to_nix

    _(nix_parse(transpiled)).must_equal nix_parse(
      <<~EOF,
      (let __yixe_top = {
        inputs = {
          nixpkgs = (
            import ((builtins).fetchTarball "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz") { }
          );
        };
        hello = (__yixe_top).inputs.nixpkgs.hello;
      }; in __yixe_top)
      EOF
    )
  end
end
