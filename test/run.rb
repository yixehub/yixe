require "minitest/cc"
Minitest::Cc.start
Minitest::Cc.cc_mode = :per_file
Minitest::Cc.tracked_files = [
  "#{__dir__()}/../lib/**/*.rb",
]

[
  "nix/test_to_nix.rb",
  "yixe/test_to_nix.rb",
  "yixe/integration_tests.rb",
].each do |path|
  load File.join(__dir__(), path)
end

result = Minitest.run()

if ARGV.include?("--verbose")
  puts <<EOF

* * *

Details:
--------

EOF

  Minitest::Cc.instance_exec() do
    files = tracked_files.map { |patt| Dir.glob(patt).map { File.realpath(_1) } }.flatten.uniq
    files.each do |file|
      next unless result_for_file(file)

      results = result_for_file(file)

      methods =
        results[:methods]
          .select { |_k, v| v.zero? }
          .keys
          .sort { |a, b| a[2] <=> b[2] }

      branches =
        results[:branches].select { |_, construct_branches| construct_branches.any? { |_, usage| usage.zero? } }

      next if methods.empty? && branches.empty?

      puts <<~EOF

      ### `#{file}`

      EOF

      unless methods.empty?
        puts <<~EOF

        #### Methods not exercised:

        EOF

        methods
          .each do |method|
          puts " - #{method[0]}##{method[1]} at line #{method[2]}"
        end
        puts ""
      end

      next if branches.empty?

      puts <<~EOF

        #### Branches not exercised:

      EOF

      branches.each do |construct, construct_branches|
        puts "For #{construct[0]} at line #{construct[2]}:"
        construct_branches.select { |_, usage| usage.zero? }.each_key do |branch|
          puts " - #{branch[0]} at line #{branch[2]}"
        end
      end
      puts ""
    end
  end

  puts <<EOF

... done!
EOF

end

if result
  exit 0
else
  exit 1
end
