# LmdbDump

Plain ruby implementation of the [LMDB](https://symas.com/lmdb/) dump format.  

## Installation

Install the gem and add to the application's Gemfile by executing:

```shell
bundle add lmdb_dump
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
gem install lmdb_dump
```

## Usage

```ruby
require "lmdb"
require "lmdb_dump"

# create a backup of the environment
File.open("path/to/backup", "w") do |file|
  LMDB.new("path/to/env") do |env|
    LmdbDump.dump(env, file, format: FORMAT_BYTE)
  end
end

# Iterate over backup
File.open("path/to/backup", "r") do |file|
  dump = LmdbDump::Deserializer.new(file)
  dump.each do |dump_db|
    puts "Values for DB #{dump_db.name}"
    dump_db.entries do |k, v|
      puts "  #{k} => #{v}"
    end
  end
end
```

## Known issues

- `mdb_dump`/`mdb_load` prior to version 0.9.25 had a bug escaping backslashes in printable content.
  `LmdbDump` does not support this bug. For best compatibility do not use the `mdb_dump`s `-p` flag
  and the (default) `FORMAT_BYTE` format in `LmdbDump`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/fnordfish/lmdb_dump>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fnordfish/lmdb_dump/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the LmdbDump project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fnordfish/lmdb_dump/blob/main/CODE_OF_CONDUCT.md).
