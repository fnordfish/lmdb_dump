# frozen_string_literal: true

RSpec.describe LmdbDump do
  it "has a version number" do
    expect(LmdbDump::VERSION).not_to be nil
  end

  describe "#find_databases" do
    it "returns nil if there are no subdatabase" do
      expect(LmdbDump.find_databases(lmdb_env)).to eq(nil)
    end

    it "returns the names of all subdatabases" do
      lmdb_env.database.put("key", "value")
      lmdb_env.database("subdb1", create: true)
      lmdb_env.database("subdb2", create: true)
      expect(LmdbDump.find_databases(lmdb_env)).to contain_exactly("subdb1", "subdb2")
    end
  end

  describe "#dump" do
    let(:io) { instance_double(IO) }
    let(:all) { double("all flag") }
    let(:subdbs) { double("subdbs array") }
    let(:fmt) { double("format") }

    subject { instance_double(LmdbDump::Serializer) }

    it "raises ArgumentError when given no LMDB::Environment or LMDB::Database" do
      expect {
        LmdbDump.dump(Object.new)
      }.to raise_error(ArgumentError, /Unknown type/)
    end

    it "dumps an LMDB::Environment into given IO, forwarding +all+ and +subsdb+ args" do
      env = lmdb_env
      expect(LmdbDump::Serializer).to receive(:new).with(io).and_return(subject)
      expect(subject).to receive(:dump_env).with(env, subdbs, all: all, format: fmt)
      retval = LmdbDump.dump(env, io, subdbs: subdbs, all: all, format: fmt)
      expect(retval).to eq(io)
    end

    it "dumps an LMDB::Environment as String when no IO given" do
      env = lmdb_env
      expect(LmdbDump::Serializer).to receive(:new).and_wrap_original do |m, *args|
        expect(args.length).to eq(1)
        expect(args.first).to be_a(::StringIO)
        args.first << "DUMPED ENV"
        subject
      end
      expect(subject).to receive(:dump_env).with(env, subdbs, all: all, format: fmt)
      retval = LmdbDump.dump(env, subdbs: subdbs, all: all, format: fmt)
      expect(retval).to eq("DUMPED ENV")
    end

    it "dumps a LMDB::Database into given IO, ignoring +all+ and +subsdb+ args" do
      db = lmdb_env.database("db", create: true)
      expect(LmdbDump::Serializer).to receive(:new).with(io).and_return(subject)
      expect(subject).to receive(:dump_db).with(db, format: fmt)
      retval = LmdbDump.dump(db, io, all: all, subdbs: subdbs, format: fmt)
      expect(retval).to eq(io)
    end

    it "dumps a LMDB::Database as String when no IO given" do
      db = lmdb_env.database("db", create: true)
      expect(LmdbDump::Serializer).to receive(:new).and_wrap_original do |m, *args|
        expect(args.length).to eq(1)
        expect(args.first).to be_a(::StringIO)
        args.first << "DUMPED DB"
        subject
      end
      expect(subject).to receive(:dump_db).with(db, format: fmt)
      retval = LmdbDump.dump(db, format: fmt)
      expect(retval).to eq("DUMPED DB")
    end
  end

  describe "#restore" do
    context "with a default database dump" do
      let(:dump_path) { fixture_file("default_env.bin.dump") }
      let(:env_path) { temp_dir("default_env") }

      specify "restores data into new env" do
        dump_path.open do |input|
          LmdbDump.restore(input, env_path)
        end

        restored_data = LMDB.new(env_path) do |env|
          env.database.to_h do |k, v|
            [k.force_encoding(Encoding::UTF_8), v.force_encoding(Encoding::UTF_8)]
          end
        end

        expect(restored_data).to eq(source_data)
      end

      specify "restores data into existing clean env" do
        env = LMDB.new(env_path)
        dump_path.open do |input|
          LmdbDump.restore(input, env)
        end

        restored_data = env.database.to_h do |k, v|
          [k.force_encoding(Encoding::UTF_8), v.force_encoding(Encoding::UTF_8)]
        end

        expect(restored_data).to eq(source_data)
      ensure
        env&.close
      end

      describe "restores data into existing env with data" do
        it "whith :clear => true, clears old data" do
          env = LMDB.new(env_path)
          db = env.database
          db["preexisting"] = "data"
          dump_path.open do |input|
            LmdbDump.restore(input, env, clear: true)
          end
          expect(db.has?("preexisting")).to be(false)
        ensure
          env&.close
        end

        it "whith :clear => false, keeps old data" do
          env = LMDB.new(env_path)
          db = env.database
          db["preexisting"] = "data"
          dump_path.open do |input|
            LmdbDump.restore(input, env, clear: false)
          end
          expect(db.has?("preexisting")).to be(true)
        ensure
          env&.close
        end
      end
    end

    context "with a subdatabase dump" do
      let(:dump_path) { fixture_file("sub_db_env.bin.dump") }
      let(:env_path) { temp_dir("sub_db_env") }

      specify "restores data into new env" do
        dump_path.open do |input|
          LmdbDump.restore(input, env_path)
        end

        restored_data = LMDB.new(env_path) do |env|
          expect(env).to be_a(LMDB::Environment)
          expect(env.database.keys).to contain_exactly("sub_db")

          db = env.database("sub_db", create: false)
          expect(db).to be_a(LMDB::Database)

          db.to_h do |k, v|
            [k.force_encoding(Encoding::UTF_8), v.force_encoding(Encoding::UTF_8)]
          end
        end

        expect(restored_data).to eq(source_data)
      end

      specify "restores data into existing env" do
        env = LMDB.new(env_path)
        expect(env.database.keys).to be_empty

        dump_path.open do |input|
          LmdbDump.restore(input, env)
        end

        expect(env.database.keys).to contain_exactly("sub_db")
        db = env.database("sub_db", create: false)
        expect(db).to be_a(LMDB::Database)

        restored_data = db.to_h do |k, v|
          [k.force_encoding(Encoding::UTF_8), v.force_encoding(Encoding::UTF_8)]
        end

        expect(restored_data).to eq(source_data)
      ensure
        env&.close
      end

      describe "restores data into existing env with data" do
        it "whith :clear => true, clears old data" do
          env = LMDB.new(env_path)
          db = env.database("sub_db", create: true)
          db["preexisting"] = "data"
          dump_path.open do |input|
            LmdbDump.restore(input, env, clear: true)
          end
          expect(db.has?("preexisting")).to be(false)
        ensure
          env&.close
        end

        it "whith :clear => false, keeps old data" do
          env = LMDB.new(env_path)
          db = env.database("sub_db", create: true)
          db["preexisting"] = "data"
          dump_path.open do |input|
            LmdbDump.restore(input, env, clear: false)
          end
          expect(db["preexisting"]).to eq("data")
        ensure
          env&.close
        end

        it "only clears the subdatabase included in the dump" do
          env = LMDB.new(env_path)
          db = env.database("other_sub_db", create: true)
          db["preexisting"] = "data"

          dump_path.open do |input|
            LmdbDump.restore(input, env, clear: true)
          end

          expect(db["preexisting"]).to eq("data")
          sub_db_data = env.database("sub_db", create: false).to_h do |k, v|
            [k.force_encoding(Encoding::UTF_8), v.force_encoding(Encoding::UTF_8)]
          end
          expect(sub_db_data).to eq(source_data)
        end
      end
    end
  end
end
