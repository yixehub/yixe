# Tests for the classes representing Nix constructs.

require "minitest/spec"
require_relative "../../lib/nix"

describe Nix do
  it "has the IMPORT helper" do
    _(Nix::IMPORT.to_nix()).must_equal "import"
  end
end

describe Nix::Raw do
  it "outputs the provided code as-is." do
    _(Nix::Raw.new("foo").to_nix()).must_equal "foo"
  end
  it "even outputs 'invalid' input." do
    _(Nix::Raw.new("<<< what's this ?").to_nix()).must_equal "<<< what's this ?"
  end
end

class NixStringWrapper < String
  using Nix::StringUtils

  def _to_nix()
    to_nix()
  end
end

describe Nix::StringUtils do
  it "serializes a Ruby string to a Nix string" do
    _(NixStringWrapper.new("a")._to_nix).must_equal %q{"a"}
  end
  it "serializes escape sequences correctly" do
    _(NixStringWrapper.new("\ehi")._to_nix).must_equal %{"${builtins.fromJSON #{"\ehi".to_json().to_json()}}"}
  end
  it "does not allow Nix antiquotation" do
    _(NixStringWrapper.new(%q{echo ${builtins.nixVersion}})._to_nix)
      .must_equal(
        %q<"${builtins.fromJSON "\"echo \\${builtins.nixVersion}\""}">,
      )
  end
end

describe Nix::List do
  it "can output an empty list" do
    _(Nix::List.new().to_nix()).must_equal "[ /* (empty) */ ]"
  end

  it "can output one item in a list" do
    l = Nix::List.new()
    l.append Nix::Raw.new("item")
    _(l.to_nix()).must_equal "[\n  (item)\n]"
  end

  it "keeps proper ordering" do
    l = Nix::List.new()
    l.append Nix::Raw.new("one")
    l.append Nix::Raw.new("two")
    _(l.to_nix()).must_equal "[\n  (one)\n  (two)\n]"
  end
end

describe Nix::Attrs do
  it "can output an empty attrset" do
    _(Nix::Attrs.new().to_nix()).must_equal "{ /* (empty) */ }"
  end

  it "can output one pair" do
    attrs = Nix::Attrs.new()
    attrs[Nix::Raw.new("item")] = Nix::Raw.new("value")
    _(attrs.to_nix()).must_equal "{\n  item = value;\n}"
  end

  it "keeps proper ordering" do
    attrs = Nix::Attrs.new()
    attrs[Nix::Raw.new("b_first")] = Nix::Raw.new("value")
    attrs[Nix::Raw.new("a_second")] = Nix::Raw.new("value2")
    _(attrs.to_nix()).must_equal "{\n  b_first = value;\n  a_second = value2;\n}"
  end

  it "allows accessing set values" do
    attrs = Nix::Attrs.new()
    attrs["a"] = "b"
    _(attrs["a"]).must_equal "b"
  end

  it "makes `rec` pattern possible" do
    attrs = Nix::Attrs.new()
    attrs.rec = true
    _(attrs.to_nix()).must_equal("rec { /* (empty) */ }")
    attrs[Nix::Raw.new("item")] = Nix::Raw.new("value")
    _(attrs.to_nix()).must_equal("rec {\n  item = value;\n}")
  end
end

describe Nix::Let do
  before do
    @value = Nix::Raw.new("value")
  end

  it "can output an empty let block" do
    let = Nix::Let.new()
    let.value = @value
    _(let.to_nix()).must_equal "let\nin\n  value"
  end

  it "takes in pairs in the scope like an Attrs does" do
    let = Nix::Let.new()
    let.value = @value
    let[Nix::Raw.new("item")] = @value
    _(let.to_nix()).must_equal "let\n  item = value;\nin\n  value"
  end

  it "keeps ordering" do
    let = Nix::Let.new()
    let.value = @value
    let[Nix::Raw.new("d")] = @value
    let[Nix::Raw.new("a")] = @value
    _(let.to_nix()).must_equal "let\n  d = value;\n  a = value;\nin\n  value"
  end
end

describe Nix::FunctionCall do
  it "outputs a function call with one arg" do
    _(Nix::FunctionCall.new(Nix::Raw.new("a"), Nix::Raw.new("b")).to_nix()).must_equal "(\n  (a)\n  (b)\n)"
  end
  it "outputs a function call with two args" do
    _(Nix::FunctionCall.new(Nix::Raw.new("a"), Nix::Raw.new("b"), Nix::Raw.new("c")).to_nix()).must_equal "(\n  (a)\n  (b)\n  (c)\n)"
  end
end

describe Nix::FunctionDefinition do
  it "outputs a trivial function definition" do
    _(Nix::FunctionDefinition.new(Nix::Raw.new("a"), Nix::Raw.new("b")).to_nix()).must_equal "(a: (b))"
  end
end

# Reminder: this is invalid Nix by itself.
# It is provided to a FunctionDefinition.
describe Nix::SetPattern do
  it "fails when no parameter given" do
    # FIXME
    # _(Nix::SetPattern.new().to_nix()).must_raise(RuntimeError)
  end
  it "outputs a trivial set-pattern argument with one argument" do
    _(Nix::SetPattern.new(Nix::Raw.new("a")).to_nix()).must_equal "{ a }"
  end
  it "outputs a less trivial set-pattern argument with two arguments" do
    _(Nix::SetPattern.new(Nix::Raw.new("a"), Nix::Raw.new("b")).to_nix()).must_equal "{ a\n, b\n}"
  end
end
