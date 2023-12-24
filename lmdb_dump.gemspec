# frozen_string_literal: true

require_relative "lib/lmdb_dump/version"

Gem::Specification.new do |spec|
  spec.name = "lmdb_dump"
  spec.version = LmdbDump::VERSION
  spec.authors = ["Robert Schulze"]
  spec.email = ["robert@dotless.de"]

  spec.summary = "Write and read portable LMDB dump files."
  spec.description = "Reimplements the dump format used in mdb_load and mdb_dump of the LMDB Tools in ruby."
  spec.homepage = "https://github.com/fnordfish/lmdb_dump"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fnordfish/lmdb_dump"
  spec.metadata["changelog_uri"] = "https://gitub.com/fnordfish/lmdb_dump/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ spec/ Rakefile .])
    end
  end
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = %w[LICENSE.txt README.md]

  spec.add_runtime_dependency "lmdb"
  spec.add_runtime_dependency "stringio"

  spec.add_development_dependency "yard"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "standard", "~> 1.3"
end
