# frozen_string_literal: true

RSpec.describe LmdbDump::Serializer do
  let(:io) { StringIO.new }
  subject { described_class.new(io) }

  describe "dumps the default database" do
    let(:env_path) { fixture_file("default_env").to_s }
    let(:all_flag) { false }

    it "as text format" do
      with_env(env_path) do |env|
        subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_TEXT)
      end

      expect(io.string).to eq(load_fixture("default_env.txt.dump"))
    end

    it "as byte format" do
      with_env(env_path) do |env|
        subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_BYTE)
      end

      expect(io.string).to eq(load_fixture("default_env.bin.dump"))
    end
  end

  describe "dump all subdatabases" do
    let(:env_path) { fixture_file("sub_db_env").to_s }
    let(:all_flag) { true }

    it "as text format" do
      with_env(env_path) do |env|
        subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_TEXT)
      end

      expect(io.string).to eq(load_fixture("sub_db_env.txt.dump"))
    end

    it "as byte format" do
      with_env(env_path) do |env|
        subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_BYTE)
      end

      expect(io.string).to eq(load_fixture("sub_db_env.bin.dump"))
    end
  end

  # Environment with data in main database and subdatabase
  describe "mixed environemnt" do
    let(:env_name) { "mixed_env" }
    let(:env_path) { fixture_file(env_name).to_s }

    context "dump subdatabases" do
      let(:all_flag) { true }
      let(:dump_name) { "#{env_name}_with_subdb" }

      it "as text format" do
        with_env(env_path) do |env|
          subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_TEXT)
        end

        expect(io.string).to eq(load_fixture("#{dump_name}.txt.dump"))
      end

      it "as byte format" do
        with_env(env_path) do |env|
          subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_BYTE)
        end

        expect(io.string).to eq(load_fixture("#{dump_name}.bin.dump"))
      end
    end

    context "dump only main database" do
      let(:all_flag) { false }
      let(:dump_name) { "#{env_name}_no_subdb" }

      it "as text format" do
        with_env(env_path) do |env|
          subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_TEXT)
        end

        expect(io.string).to eq(load_fixture("#{dump_name}.txt.dump"))
      end

      it "as byte format" do
        with_env(env_path) do |env|
          subject.dump_env(env, all: all_flag, format: LmdbDump::FORMAT_BYTE)
        end

        expect(io.string).to eq(load_fixture("#{dump_name}.bin.dump"))
      end
    end
  end

  describe "#dump_db" do
    it "throws ArgumentError when given unknown format" do
      db = lmdb_env.database
      expect {
        subject.dump_db(db, format: "unknown")
      }.to raise_error(ArgumentError, /Unknown format/)
    end
  end

  describe "#header" do
    it "skips mapaddr when it is 0" do
      db = lmdb_env.database
      expect(db.env.info[:mapaddr]).to eq(0)
      headers = subject.send(:header, db, format: LmdbDump::FORMAT_TEXT)
      expect(headers).not_to include("mapaddr=")
    end

    it "includes mapaddr when it is not 0" do
      db = lmdb_env(fixedmap: true).database
      mapaddr = db.env.info[:mapaddr]
      expect(mapaddr).not_to eq(0)
      headers = subject.send(:header, db, format: LmdbDump::FORMAT_TEXT)
      expect(headers).to include("mapaddr=#{mapaddr}")
    end
  end
end
