# frozen_string_literal: true

RSpec.describe LmdbDump::Deserializer do
  let(:io) { StringIO.new }
  subject { described_class.new(io) }

  describe "loads dump with default database" do
    it "from text dump" do
      read_data = {}
      db_name, db_options, env_options, dump_format = nil

      fixture_file("default_env.txt.dump").open do |f|
        reader = described_class.new(f)
        reader.each do |db|
          expect(db).to be_a(LmdbDump::Deserializer::Database)
          db.entries do |k, v|
            read_data[k] = v
          end
          db_name = db.name
          db_options = db.db_options
          env_options = db.env_options
          dump_format = db.format
        end
      end

      expect(db_name).to eq(nil)
      expect(read_data).to eq(source_data)
    end

    it "from byte dump" do
      read_data = {}
      db_name, db_options, env_options, dump_format = nil

      fixture_file("default_env.bin.dump").open do |f|
        reader = described_class.new(f)
        reader.each do |db|
          expect(db).to be_a(LmdbDump::Deserializer::Database)
          db.entries do |k, v|
            read_data[k] = v
          end
          db_name = db.name
          db_options = db.db_options
          env_options = db.env_options
          dump_format = db.format
        end
      end

      expect(db_name).to eq(nil)
      expect(read_data).to eq(source_data)
    end
  end

  describe "loads dump with subdatabases" do
    it "from text dump" do
      read_data = {}
      db_name, db_options, env_options, dump_format = nil

      fixture_file("sub_db_env.txt.dump").open do |f|
        reader = described_class.new(f)
        reader.each do |db|
          expect(db).to be_a(LmdbDump::Deserializer::Database)
          db.entries do |k, v|
            read_data[k] = v
          end
          db_name = db.name
          db_options = db.db_options
          env_options = db.env_options
          dump_format = db.format
        end
      end

      expect(db_name).to eq("sub_db")
      expect(read_data).to eq(source_data)
    end

    it "from byte dump" do
      read_data = {}
      db_name, db_options, env_options, dump_format = nil

      fixture_file("sub_db_env.bin.dump").open do |f|
        reader = described_class.new(f)
        reader.each do |db|
          expect(db).to be_a(LmdbDump::Deserializer::Database)
          db.entries do |k, v|
            read_data[k] = v
          end
          db_name = db.name
          db_options = db.db_options
          env_options = db.env_options
          dump_format = db.format
        end
      end

      expect(db_name).to eq("sub_db")
      expect(read_data).to eq(source_data)
    end
  end
end
