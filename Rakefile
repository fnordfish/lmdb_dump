# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"
require "yard"

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc "Create fixtures for specs (you need to have mdb_dump installed, will pick up bin/mdb_dump automatically)"
  task :create_fixtures do
    require_relative "spec/support/lmdb_helpers"
    LMDBHelpers.create_fixtures!(true)
  end
end

desc "Generate documentation"
task :docs do
  Rake::Task["docs:yard"].invoke
end

namespace :docs do
  YARD::Rake::YardocTask.new do |t|
    t.files = ["lib/**/*.rb"]
    t.options = []
    t.stats_options = ["--list-undoc"]
  end

  task :fswatch do
    sh 'fswatch -0 lib | while read -d "" e; do rake docs:yard; done'
  end
end

task default: %i[spec standard]

# Using the main source repo instead of the mirror
LMDB_SOURCE = "https://git.openldap.org/openldap/openldap.git"
LMDB_DIR = "tmp/openldap/libraries/liblmdb"
LMDB_TOOLS = %w[mdb_dump]
namespace :lmdb_tools do
  directory(LMDB_DIR) do
    mkdir_p("tmp")
    Dir.chdir("tmp") do
      sh "git clone --sparse --depth=1 #{LMDB_SOURCE} openldap"
      sh "git -C openldap sparse-checkout add libraries/liblmdb"
    end
  end

  task build: [LMDB_DIR] do
    sh "cd #{LMDB_DIR} && make"
  end

  task install: :build do
    LMDB_TOOLS.each do |tool|
      cp File.join(LMDB_DIR, tool), File.join("bin", tool)
    end
  end

  desc "Delete liblmdb source and compiled tools"
  task :clean do
    rm_rf("tmp/openldap")
    LMDB_TOOLS.each do |tool|
      rm_f("bin/#{tool}")
    end
  end
end

desc "Download, build and install mdb_dump into ./bin"
task lmdb_tools: %w[lmdb_tools:install]
