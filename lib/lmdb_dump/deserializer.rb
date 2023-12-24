# frozen_string_literal: true

module LmdbDump
  # Load a LMDB environment or database dump.
  #
  # @example
  #   File.open("environment.dump", "r") do |file|
  #     dump = LmdbDump::Deserializer.new(file)
  #     dump.each do |dump_db|
  #       puts "Values for DB #{dump_db.name}"
  #       dump_db.entries do |k, v|
  #         puts "  #{k} => #{v}"
  #       end
  #     end
  #   end
  class Deserializer
    # @param io [IO] The IO to read the dump from.
    # @param target_encoding [Encoding] The encoding to use for the strings in the dump.
    def initialize(io, target_encoding: Encoding::UTF_8)
      @io = io
      @target_encoding = target_encoding
    end

    # @return [IO]
    attr_reader :io

    # @return [Encoding]
    attr_reader :target_encoding

    # iterate over databases in environment dump
    # @yield [LmdbDump::Deserializer::Database]
    # @return [void]
    def each
      until io.eof?
        until io.eof?
          break if io.gets(chomp: true) == "VERSION=3"
        end

        yield(Database.new(io, target_encoding: target_encoding))
      end
    end

    # A single database in the dump.
    # @note The given {io} must be positioned at the start of the database.
    class Database
      # @param io [IO] The IO to read the dump from.
      # @param target_encoding [Encoding] The encoding to use for the strings in the dump.
      def initialize(io, target_encoding: Encoding::UTF_8)
        @io = io
        @_headers_read = false
        @target_encoding = target_encoding
      end

      # Name of this database.
      # @return [String]
      def name
        read_header!
        @name
      end

      # Open db_options for this database for +LMDB::Environment#database+
      # @return [Hash<Symbol, Boolean>]
      def db_options
        read_header!
        @db_options
      end

      # Environment env_options for this database for +LMDB::Environment.new+
      # @return [Hash<Symbol, Integer>]
      def env_options
        read_header!
        @env_options
      end

      # Format of this database.
      # @return [String] Either {FORMAT_TEXT} or {FORMAT_BYTE}
      def format
        read_header!
        @format
      end

      # Iterate over entries in this database.
      #
      # @yield [Array<String>] Tuple of key, value Strings
      def entries(&block)
        read_header!

        parser = case format
        when FORMAT_TEXT
          method(:decode_text)
        when FORMAT_BYTE
          method(:decode_bytes)
        else
          raise ArgumentError, "Unknown format: #{format.inspect}"
        end

        line_enum(parser).each_slice(2, &block)
      end

      # @return [Enumerator<String>] The lines of the dump for this database. Lines are keys/values alternating.
      private def line_enum(parser)
        Enumerator.new do |y|
          @io.each_line do |line|
            break if line == "DATA=END\n"

            # remove leading space and trailing newline
            str = line[1, line.length - 2]
            value = parser.call(str)
            y << value
          end
        end
      end

      private def read_header!
        return if @_headers_read

        @db_options = {}
        @env_options = {}

        @io.each_line(chomp: true) do |line|
          break if line == "HEADER=END"

          key, value = line.chomp.split("=", 2)
          if (k = DB_OPTIONS.key(key))
            @db_options[k] = (value == "1")
            next
          end

          if (k = ENV_OPTIONS.key(key))
            @env_options[k] = Integer(value)
            next
          end

          case key
          when "format"
            @format = value
          when "database"
            @name = value
          end
        end

        @_headers_read = true
      end

      # transform \c3 into \xC3 so that we can easily unpack it like normal hex string
      DUMP_HEX_TO_RUBY_HEX_MATCH = /(?<!\\)\\(\h{2})/
      private_constant :DUMP_HEX_TO_RUBY_HEX_MATCH

      # @param str [String]
      # @return [String]
      private def decode_text(str)
        str.gsub!(DUMP_HEX_TO_RUBY_HEX_MATCH) { |m| m[1, 2].to_s.hex.chr }
        str = str.unpack1("A*").to_s
        str.gsub!("\\\\", "\\")
        str.force_encoding(@target_encoding)
      end

      private def decode_bytes(str)
        decoded = String.new(capacity: str.length / 2)
        buff = String.new(capacity: 2)
        strio = StringIO.new(str)
        strio.binmode
        until strio.eof?
          decoded << strio.read(2, buff).to_s.hex.chr
        end
        decoded.force_encoding(@target_encoding)
      end
    end
  end
end
