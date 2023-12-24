# frozen_string_literal: true

RSpec.describe LmdbDump::Deserializer::Database do
  describe "#entries" do
    it "raises ArgumentError when dump uses unknown format" do
      dump = load_fixture("default_env.bin.dump")
      dump["format=#{LmdbDump::FORMAT_BYTE}"] = "format=unknown"
      io = StringIO.new(dump)
      deserializer = LmdbDump::Deserializer.new(io)

      expect {
        deserializer.each { |db|
          db.entries { |k, v| }
        }
      }.to raise_error(ArgumentError, /Unknown format/)
    end
  end

  describe "#db_options" do
    it "read db flags when present" do
      io = fixture_file("default_env.bin.dump").open
      io.gets(chomp: true) # skip firt line "VERSION=3"

      dump = StringIO.new
      LmdbDump::DB_OPTIONS.each do |k, s|
        dump << "#{s}=1\n"
      end
      dump.write(io.read)
      dump.rewind

      deserializer_db = LmdbDump::Deserializer::Database.new(dump)
      expect(deserializer_db.db_options).to eq(LmdbDump::DB_OPTIONS.keys.to_h { |k| [k, true] })
    ensure
      io&.close
    end

    it "skip db flags when not present" do
      io = fixture_file("default_env.bin.dump").open
      io.gets(chomp: true) # skip firt line "VERSION=3"
      deserializer_db = LmdbDump::Deserializer::Database.new(io)
      expect(deserializer_db.db_options).to eq({})
    ensure
      io&.close
    end
  end
end
