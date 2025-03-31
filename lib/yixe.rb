require "yaml"

module Yixe
  VERSION = 0
end

require_relative "yixe/elided"
require_relative "yixe/ir"
require_relative "yixe/nodes"
require_relative "yixe/inputs"
require_relative "yixe/nodes_to_nix"
require_relative "yixe/tag"
require_relative "yixe/tag_sets"

module Yixe
  # Implements the Psych visitor pattern for Yixe documents
  # TODO: visitor exception that shows line/column for current node.
  class YAMLVisitor < Psych::Visitors::Visitor
    attr_accessor :root
    attr_reader :document

    def initialize(document:)
      @document = document
    end

    def accept(target, type: nil)
      return super(target) unless type

      make_yixe_ast_node(target, type)
    end

    def make_yixe_ast_node(node, type)
      if type == Yixe::IR::Root
        Yixe::IR::Root.new(visitor: self, node: node, document: document)
      else
        if node.tag
          type = root.find_tag(node)

          raise "Could not find type to handle tag #{node.tag.inspect}" unless type
        end

        raise "Unexpected type #{type.inspect}" unless type.is_a?(Class) && type <= Yixe::IR::Node

        type.new(visitor: self, node: node)
      end
    end

    def visit_Psych_Nodes_Scalar(node)
      type =
        case node.value
        when String
          # TODO: Numbers, when not quoted (hex 0x..., binary 0b..., octal 0..., and then decimal)
          # TODO: Floating point, when not quoted, only decimal supported
          # FIXME: Only when not quoted!!!
          if node.quoted
            Yixe::IR::String
          else
            case node.value
            when "", "null"
              Yixe::IR::Null
            when "true", "false"
              Yixe::IR::Boolean
            when "0", /^-?[1-9][0-9]*$/, /^-?0x[0-9a-fA-F]+$/, /^-?0b[01]+$/, /^-?0[1-7][0-7]*$/
              Yixe::IR::Number
            when /[.~]?(#{Yixe::IR::Path::PATH_COMPONENT_MATCH})+/
              Yixe::IR::Path
            else
              Yixe::IR::String
            end
          end
        else
          raise "Unexpected scalar type #{node.value.class.name}"
        end
      make_yixe_ast_node(node, type)
    end

    def visit_Psych_Nodes_Sequence(node)
      make_yixe_ast_node(node, Yixe::IR::List)
    end

    def visit_Psych_Nodes_Mapping(node, is_root: false)
      type =
        if is_root
          Yixe::IR::Root
        else
          Yixe::IR::Mapping
        end

      make_yixe_ast_node(node, type)
    end

    def visit_Psych_Nodes_Document(_doc)
      raise "visiting Document not supported."
    end

    def visit_Psych_Nodes_Stream(_stream)
      raise "visiting Stream not supported."
    end

    def visit_Psych_Nodes_Alias(_alias)
      raise "visiting Alias not supported."
    end
  end

  # A Yixe document
  class Document
    attr_reader :path

    def initialize(doc, path:)
      @path = path
      doc = YAML.parse(doc)

      unless doc
        raise [
          "This does not look like a valid Yixe document...",
        ].join(" ")
      end

      # This is some slight validation of the document,
      # and is linked to the Psych representation.
      unless doc.root.mapping?
        raise [
          "Unexpected yixe document structure.",
          "Got a #{doc.root.class.name.split("::").last} at the root, instead of a Mapping.",
        ].join(" ")
      end

      @ir = YAMLVisitor.new(document: self).visit_Psych_Nodes_Mapping(doc.root, is_root: true)
    end

    def document_type()
      @ir.document_type
    end

    def call_package_pattern?()
      if ["yixe-nixpkgs-package"].include?(document_type())
        @ir.get("arguments") && @ir.get("output")
      else
        false
      end
    end

    def root()
      @ir
    end

    def version()
      @ir.version
    end

    def to_nix()
      @ir.to_nix()
    end

    def resolve_paths!()
      @path = File.realpath(@path)
      @ir.resolve_paths!()
    end

    def update_locks()
      @ir.update_locks()
      puts "... done!"
    end
  end
end
