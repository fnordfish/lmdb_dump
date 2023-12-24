# frozen_string_literal: true

require "stringio"

module LmdbDump
  # "Text" serialization format.
  #
  # Printable characters are used as is, allowing for human readable and editable dumps.
  # However, due to system differences, what constitutes a printable character is not well defined.
  # Therefore, this format is less portable when using with `mdb_load`/`mdb_dump`.
  #
  # `LmdbDump` uses a fixes range of printable characters ({Serializer::PRINTABLE_RANGE}), which should be portable across systems.
  FORMAT_TEXT = "print"

  # "Bytes" serialization format.
  #
  # Each byte of the key and vaue strings are escaped as hex values, making this format portable across systems.
  FORMAT_BYTE = "bytevalue"

  # LMDB database options. Translates the Ruby options to the string used in dumps.
  # @see LMDB::Environment#database
  DB_OPTIONS = {
    reversekey: "reversekey",
    dupsort: "duplicates", # :sic:
    integerkey: "integerkey",
    dupfixed: "dupfixed",
    integerdup: "integerdup",
    reversedup: "reversedup"
  }.freeze

  # LMDB environment options
  # @see LMDB::Environment.new
  ENV_OPTIONS = {
    maxreaders: "maxreaders",
    maxdbs: "maxdbs",
    mapsize: "mapsize"
  }

  # Find explicis database names in the environment.
  #
  # @note Avoid using this method on environments with many keys and no explicit subdatabases.
  #       It will be slow.
  #
  # @param env [LMDB::Environment]
  # @return [Array<String>,nil] The names of all databases in the environment or nil if there is only the default one.
  def self.find_databases(env)
    dbs = env.database.keys.select do |db_name|
      # currently, there is no other way to check if a key is a subdatabase,
      # other than trying to open it and see if it raises an error.
      env.database(db_name, create: false)
    rescue
      nil
    end
    (dbs.empty? ? nil : dbs)
  end

  # Shortcut for {LmdbDump::Serializer}. Create a dump of the given LMDB environment or database.
  #
  # @param env_or_db [LMDB::Environment, LMDB::Database]
  # @param io [IO] The IO to write the dump to. If not given, a String containing the dump is returned.
  # @param subdbs [Array<String>] Dump only the given subdatabases in the environment. Ignored if {env_or_db} is a {LMDB::Database}.
  # @param all [Boolean] Dump all subdatabases in the environment. Ignored if {env_or_db} is a {LMDB::Database}.
  # @param format [String] Serialize as Text ({FORMAT_TEXT}) or Bytes ({FORMAT_BYTE})
  # @return [String, IO] The dump as a String if no {io} was given, otherwise the {io} is returned.
  def self.dump(env_or_db, io = nil, subdbs: nil, all: false, format: FORMAT_BYTE)
    out = io || StringIO.new
    serializer = Serializer.new(out)
    case env_or_db
    when LMDB::Environment
      serializer.dump_env(env_or_db, subdbs, all: all, format: format)
    when LMDB::Database
      serializer.dump_db(env_or_db, format: format)
    else
      raise ArgumentError, "Unknown type: #{env_or_db.class}"
    end
    io || out.string
  end

  # Restore a dump into a new or existing LMDB environment.
  #
  # @param io [IO] An open IO to read the dump from.
  # @param env_or_path [LMDB::Environment, String] The environment or path to the environment.
  # @param env_options [Hash] The options to use when creating the environment.
  # @param clear [Boolean] If true, the database is cleared before restoring.
  # @param target_encoding [Encoding] The encoding to use for the strings in the dump.
  # @return [void]
  def self.restore(io, env_or_path, env_options = {}, clear: true, target_encoding: Encoding::UTF_8)
    env = env_or_path if env_or_path.is_a?(LMDB::Environment)
    Deserializer.new(io, target_encoding: target_encoding).each do |db|
      env ||= LMDB::Environment.new(env_or_path, **env_options.merge(db.env_options))

      new_db = if db.name
        env.database(db.name, create: true, **db.db_options)
      else
        env.database
      end

      new_db.clear if clear

      db.entries do |k, v|
        new_db[k] = v
      end
    end
    nil
  end
end

require_relative "lmdb_dump/version"
require_relative "lmdb_dump/deserializer"
require_relative "lmdb_dump/serializer"
