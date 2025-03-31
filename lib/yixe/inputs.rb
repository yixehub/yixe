require "open3"
require "tmpdir"

NPINS_PREFIX ||= "".freeze()
NPINS ||=
  if NPINS_PREFIX == ""
    "npins"
  else
    File.join(NPINS_PREFIX, "npins")
  end
    .freeze()

module Yixe::IR # :nodoc:
  using Nix::StringUtils
  # Describes inputs for a Yixe document.
  class Inputs < Mapping
    # Describes an npins input type
    # rubocop:disable Style/ClassVars
    class NpinsInput
      @@stub = nil

      attr_reader :input_data
      attr_reader :input_name
      attr_reader :node

      def initialize(input_name, input_data, node:)
        @input_data = input_data
        @input_name = input_name
        @node = node
      end

      def npins(*args)
        cmd = [NPINS, *args]
        out, status = Open3.capture2e(*cmd)
        raise "npins (#{cmd.inspect}) unexpectedly failed:\n#{out.indent(chars: ">  ")}" unless status.success?

        out
      end

      # Returns the updated data, so the lock command can rewrite this segment.
      def updated_lock_data()
        Dir.mktmpdir("yixe.npins") do |dir|
          lockfile = File.join(dir, "sources.json")
          npins(
            "--lock-file", lockfile,
            "init", "--bare",
          )
          npins(
            "--lock-file", lockfile,
            "add",
            "--name", input_name,
            type,
            *npins_add_arguments(),
          )

          data = JSON.parse(File.read(lockfile))
          # Workaround for npins 0.3.0 and `--name` with Channel type inputs.
          if type == "channel"
            channel_name = input_data["channel"]
            if data["pins"][channel_name] && channel_name != input_name
              data["pins"][input_name] = data["pins"][channel_name]
              data["pins"].delete(channel_name)
            end
          end

          { "npins" => data }
        end
      end

      def npins_add_arguments()
        case type
        when "channel"
          input_data["channel"]
        when "github"
          raise "FIXME: implement github fetching scheme for npins"
        else
          raise "FIXME: implement other fetching schemes for npins"
        end
      end

      def type()
        input_data.keys.first()
      end

      def to_nix()
        node.error(message: "No lock file found (#{lock_path.inspect})\nPlease use `yixe lock` to update the lock file.") unless File.exist?(lock_path)
        validate_lock()
        # FIXME: use promoted to global scope sample.
        raw_input =
          Nix::Raw.new([
            Nix::FunctionCall.new(
              NpinsInput.npins_stub(),
              input_json,
            ).to_nix(),
            ".#{input_name}",
          ].join())
        Nix::FunctionCall.new(
          Nix::IMPORT,
          raw_input,
          Nix::Attrs.new(),
        ).to_nix()
      end

      def input_json()
        lock_data.to_json()
      end

      def lock_path()
        @node.root.lock_path()
      end

      def lock_data()
        return @lock_data if @lock_data

        return nil unless File.exist?(lock_path)

        data = YAML.parse_file(lock_path).to_ruby()
        data = data["inputs"]["sources"][input_name]
        unless data["npins"]
          node.error(
            message: "Invalid data in lock file for #{input_name.inspect}, expected to see `npins`, but have not found it.",
          )
        end
        @lock_data = data["npins"] if data
      end

      def lock_valid?()
        validation_errors == []
      end

      def validate_lock()
        return if lock_valid?()

        node.error(
          message: [
            "Lock invalid for input #{input_name}.",
            validation_errors().join("\n").indent(),
            "Hint: Run `yixe lock` on this document.",
          ].join("\n"),
        )
      end

      def validation_errors()
        return @validation_errors if @validation_errors

        @validation_errors = []
        npins_data = lock_data["pins"][input_name]
        case type
        when "channel"
          unless input_data["channel"] == npins_data["name"]
            @validation_errors << [
              "Channel name in Yixe document does not match locked channel name.",
              "    #{input_data["channel"]} != #{npins_data["name"]}",
            ].join("\n")
          end
          unless npins_data["type"] == "Channel"
            @validation_errors << [
              "Locked type is not a channel.",
              "    Found: #{npins_data["type"]}",
            ].join("\n")
          end
        when "github"
          raise "FIXME: implement github fetching scheme for npins"
        else
          raise "FIXME: implement other fetching schemes for npins"
        end

        @validation_errors
      end

      def self.npins_stub()
        return @@stub if @@stub

        Dir.mktmpdir("yixe.npins") do |dir|
          out, status = Open3.capture2e(NPINS, "--directory", dir, "init", "--bare")
          raise "npins unexpectedly failed:\n#{out.indent(chars: ">  ")}" unless status.success?

          code = File.read(File.join(dir, "default.nix"))

          # FIXME: promote to global yixe scope, and instead have npins_stub provide the global name.
          @@stub =
            Nix::Raw.new(
              <<~EOF,
                /* Allows embedding source information in transpiled code. */
                yixe_json_input:
                /* The following is generated from `npins`. */
                #{code
                .gsub(%r{builtins.readFile ./sources.json}, "(yixe_json_input)")
                .gsub("npins upgrade", "yixe lock")
                }
              EOF
            )
        end
      end
    end
    # rubocop:enable Style/ClassVars

    def to_nix()
      attrs = Nix::Attrs.new()

      each_input do |k, v|
        attrs[k] = handle_input(k, v)
      end

      attrs.to_nix()
    end

    def each_input(&block)
      sources = get("sources")
      return "" if sources.nil?
      raise "`sources.sources` must be a mapping" unless sources.is_a? Yixe::IR::Mapping

      sources.each(&block)
    end

    def handle_input(input_name, input_node)
      input_data = input_node.to_ruby

      type = input_data.keys.first
      case type
      when "nixos-channel"
        Nix::FunctionCall.new(
          Nix::IMPORT,
          Nix::FunctionCall.new(
            Nix::Raw.new("builtins.fetchTarball"),
            "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz",
          ),
          Nix::Attrs.new(),
        )
      when "npins"
        NpinsInput.new(input_name, input_data["npins"], node: self)
      else
        error(
          message: "No type to handle input type #{type.inspect} `#{input_data.to_json}`",
          target: input_node,
        )
      end
    end

    def update_locks()
      # stream = Psych::Nodes::Stream.new
      # stream.children << YAML.parse_file(lock_path())
      # File.write(lock_path(), stream.to_yaml())
      data = YAML.parse_file(lock_path()).to_ruby() if File.exist?(lock_path())
      data ||= {}
      # TODO: migrate to next version
      data["yixe-lock"] = "v0"
      data["inputs"] ||= {}
      data["inputs"]["sources"] ||= {}
      sources = data["inputs"]["sources"]

      each_input do |k, v|
        entry = handle_input(k, v)
        if entry.respond_to?(:updated_lock_data)
          $stderr.puts "Updating #{k}..."
          sources[k] = entry.updated_lock_data()
        end
      end

      contents = [
        "# THIS FILE IS AUTOMATICALLY GENERATED. DO NOT EDIT.",
        data.to_yaml(),
      ].join("\n")
      File.write(lock_path, contents)
    end

    def lock_path()
      @root.lock_path()
    end
  end

  class Root # :nodoc:
    def update_locks()
      if get("inputs")
        get("inputs").update_locks()
      else
        error(message: "No inputs to lock in this document.")
      end
    end

    def lock_path()
      "#{document_path}.lock"
    end
  end
end
