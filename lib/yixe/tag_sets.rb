module Yixe::IR::Tag
  module Sets
    # Represents a set of tags, that a document can use.
    class TagSet
      attr_reader :tags

      def initialize(&block)
        @extends = []
        @tags = []
        instance_exec(&block)
      end

      def add_tags(*tags)
        @tags.concat(tags)
      end

      def find_own_tag(tag)
        tags.each do |tag_class|
          return tag_class if tag_class.match(tag)
        end
        nil
      end

      def find(tag)
        ret = find_own_tag(tag)
        unless ret
          @extends.each do |set|
            ret ||= set.find(tag)
          end
        end
        ret
      end

      def include(set)
        @extends << set
      end
    end

    Tag = Yixe::IR::Tag

    NixInterop = TagSet.new() do
      add_tags(Tag::NixABICall)
      add_tags(Tag::NixRaw)
      # Must be last, as it catches leftover `!nix\.` tags.
      add_tags(Tag::NixValue)
    end

    BaseMagic = TagSet.new() do
      include(NixInterop)
      add_tags(Tag::ArgumentsRef)
      add_tags(Tag::InputsRef)
      add_tags(Tag::YixeImportDocument)
    end

    Project = TagSet.new() do
      include(BaseMagic)
      add_tags(Tag::ProjectShell)
    end

    Fleet = TagSet.new() do
      include(BaseMagic)
      add_tags(Tag::FleetVM)
    end
  end
end
