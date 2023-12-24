# frozen_string_literal: true

require "lmdb"
require "fileutils"
require "pathname"

module LMDBHelpers
  module_function

  TMP_PATH = File.join(__dir__, "tmp")

  def temp_dir(path = nil)
    (path ? File.join(TMP_PATH, path) : TMP_PATH).tap do |dir|
      FileUtils.mkpath(dir)
    end
  end

  def lmdb_env(...)
    @lmdb_env ||= begin
      env_path = temp_dir("lmdb_env")
      LMDB::Environment.new(env_path, ...)
    end
  end

  DEFAULT_DB_ARGS = {
    create: true
  }.freeze

  DEFAULT_ENV_AGRS = {
    nosubdir: true,
    # (put this to expected total num of processes * their threads) default is 126
    maxreaders: 252,
    # 100 MiB, default is 10485760 bytes
    mapsize: 100 * 1024 * 1024
  }.freeze

  def with_env(full_env_path, env_args: DEFAULT_ENV_AGRS)
    env = ::LMDB.new(full_env_path, env_args)
    yield env
  ensure
    env&.close
  end

  def fixture_file(file_name)
    Pathname.new(__dir__).parent / "fixtures" / file_name
  end

  def load_fixture(file_name)
    fixture_file(file_name).read(encoding: "UTF-8")
  end

  def source_data
    @source_data ||= eval(load_fixture("data.rb")) # standard:disable Security/Eval
  end

  def create_fixtures!(force = false)
    mdb_dump = find_executable("mdb_dump", "bin", ENV["PATH"])

    if !mdb_dump
      fail "mdb_dump not found, skipping fixture creation. Ensure that LMDB Command Line Tools are installed."
    end

    fixture_file("mdb_version.txt").open("w") { |f| system(mdb_dump, "-V", out: f) }

    data = source_data

    create_db_fixture!("sub_db_env", "sub_db", data, mdb_dump, force)
    create_db_fixture!("default_env", nil, data, mdb_dump, force)
    create_mixed_db_fixture!("mixed_env", data, mdb_dump, force)
  end

  private def create_mixed_db_fixture!(name, data, mdb_dump, force)
    env_file_name = fixture_file(name)

    return if !force && env_file_name.exist?

    LMDB.new(env_file_name, **DEFAULT_ENV_AGRS) do |env|
      db = env.database
      data.each { |k, v| db[k] = v }

      sub_db = env.database("sub_db", **DEFAULT_DB_ARGS)
      data.each { |k, v| sub_db[k] = v }
    end

    dump_db_fixture!(env_file_name.to_s, true, mdb_dump, as_name: "#{env_file_name}_with_subdb")
    dump_db_fixture!(env_file_name.to_s, false, mdb_dump, as_name: "#{env_file_name}_no_subdb")
  end

  private def create_db_fixture!(name, subdb, data, mdb_dump, force)
    env_file_name = fixture_file(name)

    return if !force && env_file_name.exist?

    LMDB.new(env_file_name, **DEFAULT_ENV_AGRS) do |env|
      db = subdb ? env.database(subdb, **DEFAULT_DB_ARGS) : env.database
      data.each { |k, v| db[k] = v }
    end

    dump_db_fixture!(env_file_name.to_s, subdb, mdb_dump)
  end

  private def dump_db_fixture!(name, dump_subdb, mdb_dump, as_name: name)
    flags = dump_subdb ? "-na" : "-n"

    fixture_file("#{as_name}.bin.dump").open("w") do |f|
      system(mdb_dump, flags, name, out: f, err: $stderr)
    end

    fixture_file("#{as_name}.txt.dump").open("w") do |f|
      system(mdb_dump, "#{flags}p", name, out: f, err: $stderr)
    end
  end

  # Searches for executable +bin+ in +path+. The default path is the `PATH` environment variable.
  # Relative paths (eg starting with "./", "../", "~/") are expanded to absolute paths.
  #
  # @param [String] bin The executable to find
  # @param [String] paths Optional path to search in, default: ENV['PATH']
  private def find_executable(bin, *paths)
    if ::File.absolute_path?(bin)
      return (::File.file?(bin) && ::File.executable?(bin)) ? bin : nil
    end

    if bin.start_with?("./", "../", "~/")
      bin = ::File.expand_path(bin)
      return (::File.file?(bin) && ::File.executable?(bin)) ? bin : nil
    end

    path = if paths.any?
      paths.each_with_object([]) { |e, a| a.push(*e.split(::File::PATH_SEPARATOR)) if e }
    elsif (env_path = ENV["PATH"])
      env_path.split(::File::PATH_SEPARATOR)
    else
      # default to a sensible default (from mkmf.rb)
      %w[/usr/local/bin /usr/ucb /usr/bin /bin]
    end

    path.each do |dir|
      file = ::File.join(dir, bin)

      return file if ::File.file?(file) && ::File.executable?(file)
    end

    nil
  end
end
