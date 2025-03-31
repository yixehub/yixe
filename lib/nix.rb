require "json"

# Namespace for Nix utilities
module Nix
  # Defines refinement allowing additional useful string manipulation
  module StringUtils
    refine String do
      def indent(n=1, chars: "  ")
        split("\n").map do |line|
          (chars * n) + line
        end
          .join("\n")
      end

      def to_nix()
        case ret = to_json
        when /\\u/, /\${/
          # This marshalling is evil, but makes it work with attrs.
          ret = to_json().to_json().gsub("${", '\\${')
          %("${builtins.fromJSON #{ret}}")
        else
          # Borrows the JSON representation directly.
          # In most cases, this should just work... right?
          ret
        end
      end
    end
  end
  using StringUtils

  # Wraps a string such that `#to_nix` returns it directly.
  # This is an escape hatch to allow non-trivial Nix constructs to be built as a string.
  class Raw
    def initialize(v)
      @v = v
    end

    def to_nix()
      @v
    end
  end

  # The `import` builtin value, conveniently already wrapped.
  IMPORT = Raw.new("import")
  # The `null` value, conveniently already wrapped.
  NULL = Raw.new("null")

  class NixValue
    # (base class)
  end

  # Represents a Nix List
  class List < NixValue
    def initialize()
      @entries = []
    end

    def append(value)
      @entries << value
    end

    def to_nix()
      return "[ /* (empty) */ ]" if @entries.empty?

      [
        "[",
        *entries_to_nix(),
        "]",
      ].join("\n")
    end

    def entries_to_nix()
      (@entries.map { "(#{_1.to_nix})" })
        .join("\n")
        .indent()
    end
  end

  # Represents a Nix Attributes set
  class Attrs < NixValue
    attr_accessor :rec

    def initialize()
      @attrs = {}
      @rec = false
    end

    def []=(name, value)
      @attrs[name] = value
    end

    def [](name)
      @attrs[name]
    end

    def to_nix()
      return "#{rec ? "rec " : ""}{ /* (empty) */ }" if @attrs.empty?

      [
        if rec
          "rec {"
        else
          "{"
        end,
        *attrs_to_nix(),
        "}",
      ].join("\n")
    end

    def attrs_to_nix()
      (@attrs.map { |k, v| attr_to_nix(k, v) })
        .join("\n")
        .indent()
    end

    def attr_to_nix(k, v)
      [
        k.to_nix(),
        " = ",
        v.to_nix(),
        ";",
      ].join
    end
  end

  # Represents a Nix let ... in binding
  # FIXME: use a shared collection baseclass instead
  class Let < Attrs
    attr_accessor :value

    def to_nix()
      scope = *attrs_to_nix()
      scope = nil if scope == [""]
      [
        "let",
        scope,
        "in",
        value.to_nix().indent(),
      ].flatten().compact().join("\n")
    end
  end

  # Represents attrsets being (shallowly) merged
  # As a convenience, allows multiple arguments to be chained, i.e.
  #  <nix>  ({/* a */} // { /* b */ })
  class MergeAttrs
    def initialize(*args)
      @args = *args
    end

    def to_nix()
      [
        "(",
        [
          @args.map { "(#{_1.to_nix})" },
        ].join("\n // \n").indent(),
        ")",
      ].join("\n")
    end
  end

  # Represents a Nix function call
  # As a convenience, allows multiple arguments to be chained, i.e.
  #  <nix>  (f) (a) (b)
  class FunctionCall
    def initialize(fn, *args)
      @fn = fn
      @args = *args
    end

    def to_nix()
      [
        "(",
        [
          "(#{@fn.to_nix})",
          @args.map { "(#{_1.to_nix})" },
        ].join("\n").indent(),
        ")",
      ].join("\n")
    end
  end

  # Represents the definition of a function
  class FunctionDefinition
    def initialize(arg, body)
      @arg = arg
      @body = body

      # raise "FunctionDefinition needs a arg, given #{arg.inspect} instead" unless arg
      # raise "FunctionDefinition needs a body, given #{body.inspect} instead" unless body
    end

    def to_nix()
      [
        "(",
        @arg.to_nix,
        ": (",
        @body.to_nix,
        ")",
        ")",
      ].join
    end
  end

  # Represents a set-pattern argument definition
  # TODO: support default values
  class SetPattern
    def initialize(*args)
      @args = args
    end

    def append(arg)
      @args << arg
    end

    def to_nix()
      if @args.empty?
        raise "SetPattern with length 0"
      elsif @args.length == 1
        "{ #{@args.first.to_nix()} }"
      else
        "{ #{@args.map(&:to_nix).join("\n, ")}\n}"
      end
    end
  end
end
