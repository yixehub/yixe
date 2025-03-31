module Yixe::IR; end # :nodoc:

# Yixe IR Tags
module Yixe::IR::Tag
  using Nix::StringUtils

  class Yixe::IR::Node # :nodoc:
    # Creates a node/tag pair out of thin air.
    def synthesize_tag(tag, value: "")
      node =
        case value
        when String
          Psych::Nodes::Scalar.new(value, nil, tag)
        end
      @visitor.accept(node)
    end
  end

  # Base class for tags
  class Base < Yixe::IR::Node
    attr_reader :value

    def initialize(node:, visitor:, **kw)
      super
      @tag = node.tag
      # Unwrap the node
      node = node.dup.tap { _1.tag = nil }
      @value = visitor.accept(node)
    end

    def self.match(_s)
      raise "#{name.inspect} did not implement `.match`"
    end

    def inspect()
      "#<#{self.class.name}:#{@tag.inspect}:#{@value.inspect}>"
    end

    def resolve_paths!()
      @value.resolve_paths!()
    end
  end

  #
  # Nix interop
  #

  # Tag used to write a raw Nix value
  class NixRaw < Base
    def to_nix()
      node.value
    end

    def self.match(s)
      s == "!nix"
    end
  end

  # Tag for Nix global scope values
  class NixValue < Base
    def to_nix()
      nix_value = Nix::Raw.new(@tag.sub(/^!nix\./, ""))

      unless value.null?
        payload =
          if node.quoted || node.style == Psych::Nodes::Scalar::DOUBLE_QUOTED
            node.value
          else
            Nix::Raw.new(node.value)
          end
        nix_value =
          Nix::FunctionCall.new(
            nix_value,
            payload,
          )
      end

      nix_value.to_nix()
    end

    def self.match(s)
      s.match(/^!nix\./)
    end
  end

  # Tag for a Nix "ABI" call
  class NixABICall < Base
    def to_nix()
      Nix::FunctionCall.new(*@value.to_a).to_nix()
    end

    def self.match(s)
      s.match(/^!call$/)
    end
  end

  #
  # Refs
  #

  # Tag to refer to the Yixe expression's arguments
  class ArgumentsRef < Base
    def to_nix()
      # FIXME: this is actually using "whatever current scope.
      # We should probably codify the scoping rules properly.
      @tag.sub(/^!arguments\./, "")
    end

    def self.match(s)
      s.match(/^!arguments\./)
    end
  end

  # Tag to refer to the Yixe expression's inputs
  class InputsRef < Base
    def to_nix()
      [
        "__yixe_top",
        @tag.sub(/^!/, ""),
      ].join(".")
    end

    def self.match(s)
      s.match(/^!inputs\./)
    end
  end

  #
  # Yixe
  #

  # Imports a Yixe document in the scope.
  # Can be paired with, for example, `callPackage` from Nixpkgs.
  class YixeImportDocument < Base
    def to_nix()
      path = @value.value
      path =
        case path
        when %r{^\./}
          @root.resolve_path(path)
        when %r{^/}
          path
        else
          raise "Unexpected path kind #{path.inspect}."
        end
      doc = File.read(path)
      doc = Yixe::Document.new(doc, path: path)

      if doc.call_package_pattern?()
        pkgs = synthesize_tag("!inputs.nixpkgs")
        Nix::FunctionCall.new(
          Nix::Raw.new("(#{pkgs.to_nix()}).callPackage"),
          doc,
          Nix::Attrs.new(),
        ).to_nix()
      else
        doc.to_nix()
      end
    end

    def self.match(s)
      s.match(/^!yixe.import-document$/)
    end
  end

  #
  # Yixe Project
  #

  # Defines a value as a Yixe Prject Shell description
  class ProjectShell < Base
    def to_nix()
      pkgs = synthesize_tag("!inputs.nixpkgs")
      packages = Nix::List.new()
      set_pattern = Nix::SetPattern.new(Nix::Raw.new("mkShell"))

      (value.get("packages") or []).map do |package|
        case package
        when Yixe::IR::String
          identifier = Nix::Raw.new(package.value)
          set_pattern.append(identifier)
          packages.append(identifier)
        when NixABICall
          packages.append(package)
        else
          raise "Unexpected type: #{package.class.inspect} in ProjectShell#to_nix"
        end
      end
      environment = value.get("environment")
      environment ||= Nix::Attrs.new()
      mk_shell_params = value.get("mkShell")
      mk_shell_params ||= Nix::Attrs.new()

      Nix::Raw.new(
        <<~EOF,
          (
            (#{pkgs.to_nix()}).callPackage (
          #{set_pattern.to_nix().indent(2)}:
              mkShell (
          #{environment.to_nix().indent(3)}
                //
          #{mk_shell_params.to_nix().indent(3)}
                // {
                  buildInputs =
          #{packages.to_nix().indent(5)}
                  ;
                }
              )
            ) {}
          )
        EOF
      ).to_nix().strip()
    end

    def self.match(s)
      s.match(/^!project\.shell$/)
    end
  end

  #
  # Yixe Fleet
  #

  # Defines a machine.
  # Implicit in a fleet output.
  class FleetSystem < YixeImportDocument
    def self.match(s)
      s.match(/^!fleet\.system$/)
    end
  end

  # Defines a machine as its VM output.
  class FleetVM < FleetSystem
    def self.match(s)
      s.match(/^!fleet\.vm$/)
    end
  end
end
