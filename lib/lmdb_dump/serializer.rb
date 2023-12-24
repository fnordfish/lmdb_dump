# frozen_string_literal: true

module LmdbDump
  # Create a LMDB environment or database dump.
  #
  # @example
  #   File.open("lmdb_env.dump", "w") do |file|
  #     LMDB.new("lmdb_env") { |env|
  #       LmdbDump::Serializer.new(file).dump_env(env)
  #     }
  #   end
  class Serializer
    # @param io [IO] The IO to write the dump to.
    def initialize(io)
      @io = io
    end

    # @return [IO]
    attr_reader :io

    # Dumps environment with its main db or subdatabases into the given {io}.
    #
    # By default, only the main database is dumped.
    # Either specify +subdbs+ to dump a specific list of subdatabases or,
    # set +all+ to `ture` to dump all subdatabases.
    #
    # @note
    #   The arguments mock the cli options of the mdb_dump tool.
    #   If you know the list of subdatabases, avoid using {all} and use {subdbs} instead.
    #
    # @param env [LMDB::Environment]
    # @param subdbs [Array<String>] Dump only the given subdatabases in the environment.
    # @param all [Boolean] Dump all subdatabases in the environment.
    # @param format [String] Serialize as Text ({FORMAT_TEXT}) or Bytes ({FORMAT_BYTE})
    # @return [void]
    def dump_env(env, subdbs = nil, all: false, format: FORMAT_BYTE)
      raise ArgumentError, "Cannot specify both subdbs and all" if subdbs && all

      subdbs ||= LmdbDump.find_databases(env) if all

      if subdbs
        subdbs.each do |db_name|
          db = env.database(db_name, create: true)
          dump_db(db, db_name: db_name, format: format)
        end
      else
        dump_db(env.database, format: format)
      end

      nil
    end

    # Dump a single database into the given {io}
    #
    # @param db [LMDB::Database]
    # @param db_name [String]
    # @param format [String] Serialize as Text ({FORMAT_TEXT}) or Bytes ({FORMAT_BYTE})
    # @return [void]
    def dump_db(db, db_name: nil, format: FORMAT_BYTE)
      dumper = case format
      when FORMAT_TEXT
        method(:encode_text)
      when FORMAT_BYTE
        method(:encode_bytes)
      else
        raise ArgumentError, "Unknown format: #{format.inspect}"
      end

      io << header(db, db_name: db_name, format: format)
      db.each do |k, v|
        io << dumper.call(k)
        io << dumper.call(v)
      end

      io.puts("DATA=END")

      nil
    end
    
    # @param db [LMDB::Database]
    # @param db_name [String]
    # @param format [String] Serialize as Text ({FORMAT_TEXT}) or Bytes ({FORMAT_BYTE})
    # @return [String] The header of the dump.
    private def header(db, db_name: nil, format: FORMAT_BYTE)
      env_info = db.env.info
      db_flags = db.flags
      db_stats = db.stat

      str = StringIO.new
      str.puts("VERSION=3")
      str.puts("format=#{format}")
      str.puts("database=#{db_name}") if db_name
      str.puts("type=btree")

      str.puts("mapsize=#{env_info[:mapsize]}")
      if (mapaddr = env_info[:mapaddr]) && mapaddr != 0
        str.puts("mapaddr=#{mapaddr}")
      end
      str.puts("maxreaders=#{env_info[:maxreaders]}")

      DB_OPTIONS.each do |k, s|
        str.puts("#{s}=1") if db_flags[k]
      end

      str.puts("db_pagesize=#{db_stats[:psize]}")
      str.puts("HEADER=END")
      str.string
    end

    ENCODING = Encoding::BINARY
    private_constant :ENCODING

    ESC_STR = "\\"
    private_constant :ESC_STR

    ESC_ORD = ESC_STR.ord
    private_constant :ESC_ORD

    SPACE = " "
    private_constant :SPACE

    NL = "\n"
    private_constant :NL

    # Range of printable characters.
    PRINTABLE_RANGE = 0x20...0x7f

    # Encode string for dump as text.
    # @param str [String] The string to encode.
    # @return [String] A new string encoded as text.
    private def encode_text(str)
      str
        .each_byte
        .inject(String.new(SPACE, capacity: str.bytesize, encoding: ENCODING)) { |out, i|
          case i
          when ESC_ORD
            out << ESC_STR
            out << ESC_STR
          when PRINTABLE_RANGE
            out << i.chr(ENCODING)
          else
            out << ESC_STR
            out << sprintf("%02x", i)
          end
        }
        .concat(NL)
    end

    # Encode string for dump as bytes.
    # @param str [String] The string to encode.
    # @return [String] A new string encoded as byte values.
    private def encode_bytes(str)
      str
        .each_byte
        .inject(String.new(SPACE, capacity: str.bytesize, encoding: ENCODING)) { |out, i|
          out << sprintf("%02x", i)
        }
        .concat(NL)
    end
  end
end
