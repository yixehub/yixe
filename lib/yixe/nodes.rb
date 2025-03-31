module Yixe # :nodoc:
  class YixeDocumentError < StandardError
  end

  using Nix::StringUtils

  module IR
    # Base class for a document Node
    class Node
      attr_reader :position
      attr_reader :root

      private def initialize(visitor:, node:)
        @root = visitor.root
        # Elided from `#inspect`...
        @node = Elided.new(node)
        @visitor = Elided.new(visitor)

        @position = {
          start_line: @node.start_line,
          start_column: @node.start_column,
          end_line: @node.end_line,
          end_column: @node.end_column,
        }
      end

      def error(message:, target: self)
        trace =
          [
            "   in:",
            "       Node: #{type}",
            "         at: in #{short_document_position}",
          ]
        unless target == self
          trace.append(
            "   target:",
            "       Node: #{target.type}",
            "         at: in #{target.short_document_position}",
          )
        end
        trace = trace.join("\n").indent()

        message = [
          "Error handling nodes in a Yixe Document",
          "",
          "Error: #{message}".indent(),
          trace,
        ].join("\n")

        raise YixeDocumentError, message
      end

      def node()
        @node.__value
      end

      def value()
        raise "`#value` not defined for #{self.class.name.inspect}"
      end

      def to_json(*args)
        @node
          .to_ruby()
          .to_json(*args)
      end

      def to_ruby()
        @node
          .to_ruby()
      end

      def short_position()
        "line #{position[:start_line]} column #{position[:start_column]}"
      end

      def short_document_position()
        "#{document_path}:#{position[:start_line]}:#{position[:start_column]}"
      end

      def document_path()
        @root.document_path
      end

      def type()
        self.class.name.split("::").last()
      end

      def null?()
        false
      end
    end

    # A document hash/mapping/attrset
    class Mapping < Node
      attr_reader :value

      def initialize(**kw)
        super
        @value = {}
        @node.children.each_slice(2) do |k, v|
          handle_pair(k, v)
        end
        @keys =
          @value.keys.to_h do |node|
            [node.value, node]
          end
      end

      def get(key)
        @value[@keys[key]]
      end

      def consume!(key)
        get(key).tap do
          delete!(key)
        end
      end

      def delete!(key)
        @value.delete(@keys[key])
        @keys.delete(key)
      end

      def keys()
        @keys.map(&:first)
      end

      def each()
        @keys.each_key do |k|
          yield(k, get(k))
        end
      end

      def resolve_paths!()
        each do |_, el|
          el.resolve_paths!() if el.is_a?(Node)
        end
      end

      protected def handle_pair(k, v)
        @value[@visitor.accept(k)] = @visitor.accept(v)
      end
    end

    # A document array/list
    class List < Node
      def initialize(**kw)
        super
        @value = @node.children.map { @visitor.accept(_1) }
      end

      def prepend(el)
        raise "Must be a #{Node.name}" unless el.is_a?(Node)

        @value.unshift(el)
      end

      def append(el)
        raise "Must be a #{Node.name}" unless el.is_a?(Node)

        @value << el
      end

      def to_a()
        @value
      end

      def map()
        @value.map { yield(_1) }
      end

      def any?()
        @value.any? { yield(_1) }
      end

      def resolve_paths!()
        map do |el|
          el.resolve_paths!() if el.is_a?(Node)
        end
      end
    end

    # The mapping at the root of the document
    # Includes some additional knowledge regarding the document implementation details.
    # TODO: different class according to document type?
    class Root < Mapping
      attr_reader :version
      attr_reader :document_type

      DocumentTypes = {
        "yixe-document": {},
        "yixe-project": {
          tags: :Project,
        },

        # A somewhat raw Nix expression.
        "yixe-expression": {},

        # Nixpkgs integration.
        "yixe-nixpkgs-package": {},

        # NixOS integration.
        "yixe-nixos-module": {},
        "yixe-nixos-fleet": {
          tags: :Fleet,
        },
      }.freeze

      def initialize(visitor:, document:, **kw)
        @document = document
        # TODO: use !no-magic document version tag for no magic.
        @tag_set = nil
        visitor.root = self
        super(**kw, visitor: visitor)
      end

      def find_tag(node)
        @tag_set.find(node.tag)
      end

      def document_path()
        @document.path
      end

      def resolve_path(rel)
        File.join(File.dirname(@document.path), rel)
      end

      protected def handle_pair(key_yaml_node, value_yaml_node)
        key_name = key_yaml_node.value
        type =
          case key_name
          when "inputs"
            Inputs
          when "outputs"
            Outputs
          end

        key_node = @visitor.accept(key_yaml_node)
        value_node = @visitor.accept(value_yaml_node, type: type)

        case key_name
        when "input"
          error(
            message: "The singular `input` name is reserved at the moment. Did you mean `inputs`?",
            target: key_node,
          )
        end

        # First value is the document type and version.
        # It is not part of the "actual" document values.
        return setup_document_type(key_node, value_node) unless @document_type

        @value[key_node] = value_node
      end

      def setup_document_type(key_node, value_node)
        @document_type = key_node.value
        @version = value_node.value
        type_info = DocumentTypes[@document_type.to_sym()]
        unless type_info
          error(
            message: "Unexpected document type: #{@document_type}; known types: #{DocumentTypes.keys.inspect}",
            target: key_node,
          )
        end

        @tag_set ||= Tag::Sets.const_get(type_info[:tags]) if type_info[:tags]
        @tag_set ||= Tag::Sets::BaseMagic
        nil
      end
    end

    class Outputs < Mapping
      # TODO: produce outputs;
      # discrete type as if tagged.
    end

    # A document string
    class String < Node
      attr_reader :value

      def initialize(**kw)
        super
        @value = @node.value
      end

      def resolve_paths!()
        # no-op
      end

      def inspect()
        "#<#{self.class.name}:#{@value.inspect}>"
      end
    end

    # A document null
    class Null < Node
      def null?()
        true
      end

      def resolve_paths!()
        # no-op
      end
    end

    # A document boolean
    class Boolean < Node
      attr_reader :value

      def initialize(**kw)
        super
        @value = @node.value == "true"
      end

      def inspect()
        "#<#{self.class.name}:#{@value.inspect}>"
      end

      def resolve_paths!()
        # no-op
      end
    end

    # A document number
    class Number < Node
      attr_reader :value

      def initialize(**kw)
        super
        base =
          case node.value
          when /^-?0x/
            16
          when /^-?0b/
            2
          when /^-?0/
            8
          else
            10
          end
        @value = @node.value.to_i(base)
      end

      def inspect()
        "#<#{self.class.name}:#{@value.inspect}>"
      end

      def resolve_paths!()
        # no-op
      end
    end

    # A path
    class Path < Node
      PATH_COMPONENT_MATCH = %r{(/[a-zA-Z0-9._+-]+)}.freeze()

      def resolve_paths!()
        node.value = root.resolve_path(node.value)
      end

      def value()
        node.value
      end
    end
  end
end
