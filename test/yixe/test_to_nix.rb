require "minitest/spec"
require_relative "../../lib/yixe"

module YixeTestHelpers
  # def appearificate_node(yaml_string, attr: "test")
  def appearificate_node(yaml_string, attr: "test")
    # This presumes `yixe-project` is sufficient.
    doc = Yixe::Document.new("yixe-document: v0\n#{yaml_string}", path: "<string>")
    ir = doc.instance_exec { @ir }
    ir.get(attr)
  end

  def nixpkgs_input
    <<~EOF
    inputs:
      sources:
        nixpkgs: { nixos-channel: nixos-unstable }
    EOF
  end

  def testing_arguments
    <<~EOF
    arguments:
      - testing
    EOF
  end
end

describe Yixe::IR::String do
  include YixeTestHelpers
  it "#to_nix converts to a Nix string" do
    _(appearificate_node("test: string value").to_nix).must_equal %q{"string value"}
  end
end

describe Yixe::IR::Null do
  include YixeTestHelpers
  it "#to_nix converts to null" do
    _(appearificate_node("test:").to_nix).must_equal %q{null}
    _(appearificate_node("test: null").to_nix).must_equal %q{null}
    _(appearificate_node("test: Null").to_nix).must_equal %q{"Null"}
  end
end

describe Yixe::IR::Boolean do
  include YixeTestHelpers
  it "#to_nix converts to true" do
    _(appearificate_node("test: true").to_nix).must_equal %q{true}
  end
  it "#to_nix converts to false" do
    _(appearificate_node("test: false").to_nix).must_equal %q{false}
  end
end

describe Yixe::IR::Number do
  include YixeTestHelpers
  it "#to_nix handles decimal" do
    _(appearificate_node("test: 1").to_nix).must_equal %q{1}
    _(appearificate_node("test: 0").to_nix).must_equal %q{0}
    _(appearificate_node("test: 4").to_nix).must_equal %q{4}
    _(appearificate_node("test: 40").to_nix).must_equal %q{40}
    _(appearificate_node(%{test: "4"}).to_nix).must_equal %q{"4"}
  end
  it "#to_nix handles hex" do
    _(appearificate_node("test: 0x0").to_nix).must_equal %q{0}
    _(appearificate_node("test: 0xA").to_nix).must_equal %q{10}
    _(appearificate_node("test: 0xf").to_nix).must_equal %q{15}
    _(appearificate_node("test: 0x10").to_nix).must_equal %q{16}
  end
  it "#to_nix handles binary" do
    _(appearificate_node("test: 0b0").to_nix).must_equal %q{0}
    _(appearificate_node("test: 0b1").to_nix).must_equal %q{1}
    _(appearificate_node("test: 0b10").to_nix).must_equal %q{2}
  end
  it "#to_nix handles octal" do
    _(appearificate_node("test: 01").to_nix).must_equal %q{1}
    _(appearificate_node("test: 02").to_nix).must_equal %q{2}
    _(appearificate_node("test: 010").to_nix).must_equal %q{8}
  end
  it "#to_nix handles negatives" do
    _(appearificate_node("test: -1").to_nix).must_equal %q{-1}
    _(appearificate_node("test: -2").to_nix).must_equal %q{-2}
    _(appearificate_node("test: -010").to_nix).must_equal %q{-8}
    _(appearificate_node("test: -0xf").to_nix).must_equal %q{-15}
  end
end

describe Yixe::IR::Mapping do
  include YixeTestHelpers
  it "#to_nix produces valid absolute paths" do
    _(appearificate_node("test: /a").to_nix).must_equal %q{/a}
    _(appearificate_node("test: /.").to_nix).must_equal %q{/.}
    _(appearificate_node("test: /+").to_nix).must_equal %q{/+}
    _(appearificate_node("test: /-").to_nix).must_equal %q{/-}
    _(appearificate_node("test: /_").to_nix).must_equal %q{/_}
    _(appearificate_node("test: /Users/samuel").to_nix).must_equal %q{/Users/samuel}
    _(appearificate_node("test: //").to_nix).must_equal %q{"//"}
    _(appearificate_node("test: /@").to_nix).must_equal %q{"/@"}
  end
  it "#to_nix produces valid relative paths" do
    _(appearificate_node("test: ./a").to_nix).must_equal %q{./a}
    _(appearificate_node("test: ./.").to_nix).must_equal %q{./.}
    _(appearificate_node("test: ./Projects/nix-crimes").to_nix).must_equal %q{./Projects/nix-crimes}
    _(appearificate_node("test: .//").to_nix).must_equal %q{".//"}
    _(appearificate_node("test: ./@").to_nix).must_equal %q{"./@"}
  end
  it "#to_nix produces valid home-relative paths" do
    _(appearificate_node("test: ~/a").to_nix).must_equal %q{~/a}
    _(appearificate_node("test: ~/.").to_nix).must_equal %q{~/.}
    _(appearificate_node("test: ~/Projects/nix-crimes").to_nix).must_equal %q{~/Projects/nix-crimes}
    _(appearificate_node("test: ~//").to_nix).must_equal %q{"~//"}
    _(appearificate_node("test: ~/@").to_nix).must_equal %q{"~/@"}
  end
end

describe Yixe::IR::Mapping do
  include YixeTestHelpers
  it "#to_nix produces empty attrs" do
    _(appearificate_node("test: {}").to_nix).must_equal %q{{ /* (empty) */ }}
  end
  it "#to_nix produces elements" do
    _(appearificate_node("test:\n  a: aa\n  b: bb").to_nix).must_equal %{{\n  "a" = "aa";\n  "b" = "bb";\n}}
  end
end

describe Yixe::IR::List do
  include YixeTestHelpers
  it "#to_nix produces empty lists" do
    _(appearificate_node("test: []").to_nix).must_equal %q{[ /* (empty) */ ]}
  end
  it "#to_nix produces proper lists" do
    _(appearificate_node("test:\n - a\n - b").to_nix).must_equal %{[\n  ("a")\n  ("b")\n]}
  end
end

describe Yixe::IR::Inputs do
  include YixeTestHelpers
  it "#to_nix handles empty inputs" do
    _(appearificate_node("inputs: { sources: {} }", attr: "inputs").to_nix).must_equal %q{{ /* (empty) */ }}
  end
  it "#to_nix produces nixos-channel inputs" do
    test = _(appearificate_node("inputs:\n  sources:\n    nixpkgs: { nixos-channel: nixos-unstable }", attr: "inputs").to_nix)
    test.must_match %r{import}
    test.must_match %r{builtins.fetchTarball}
    test.must_match "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz"
  end
end

describe Yixe::IR::Tag::InputsRef do
  include YixeTestHelpers
  it "#to_nix produces expected results" do
    _(appearificate_node("#{nixpkgs_input}\ntest: !inputs.nixpkgs").to_nix).must_equal %q{__yixe_top.inputs.nixpkgs}
  end
end

describe Yixe::IR::Tag::ArgumentsRef do
  include YixeTestHelpers
  it "#to_nix produces expected results" do
    _(appearificate_node("#{testing_arguments}\ntest: !arguments.testing").to_nix).must_equal %q{testing}
  end
end

describe Yixe::IR::Tag::NixRaw do
  include YixeTestHelpers
  it "#to_nix produces expected results" do
    _(appearificate_node("test: !nix (/* raw Nix */ 42)").to_nix).must_equal %q{(/* raw Nix */ 42)}
  end
end

describe Yixe::IR::Tag::NixValue do
  include YixeTestHelpers
  it "#to_nix produces expected results" do
    _(appearificate_node("test: !nix.builtins.nixVersion").to_nix).must_equal %q{builtins.nixVersion}
  end

  it "#to_nix produces expected results for call-type" do
    _(appearificate_node(%{test: !nix.builtins.throw builtins.nixVersion}).to_nix).must_match(
      %r{^[\s()]+builtins.throw[\s()]+builtins.nixVersion[\s()]+$}m,
    )
    _(appearificate_node(
      <<~EOF,
        test: !nix.builtins.throw |-
          builtins.nixVersion
      EOF
    ).to_nix).must_match(
      %r{^[\s()]+builtins.throw[\s()]+builtins.nixVersion[\s()]+$}m,
    )
    _(appearificate_node(
      <<~EOF,
        test: !nix.builtins.throw |-
          "stringyString"
      EOF
    ).to_nix).must_match(
      %r{^[\s()]+builtins.throw[\s()]+"stringyString"[\s()]+$}m,
    )
    _(appearificate_node(%{test: !nix.builtins.throw "stringyString"}).to_nix).must_match(
      %r{^[\s()]+builtins.throw[\s()]+"stringyString"[\s()]+$}m,
    )
  end
end

describe Yixe::IR::Tag::NixABICall do
  include YixeTestHelpers
  it "#to_nix produces expected results" do
    _(appearificate_node("test: !call\n - a\n - b").to_nix).must_equal %{(\n  ("a")\n  ("b")\n)}
  end
end
