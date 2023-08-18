# IndentCalculatorDemo

Forked from old version of tompng/katakata_irb (Nov 1, 2022 https://github.com/tompng/katakata_irb/commit/097b7064caf42d3f3db624984f3b63a1a226a232).

Merged changes made to NestingParser (Jun 16, 2023 https://github.com/tompng/katakata_irb/commit/38289e41ce7fe348a06c07258d43b1901880c30d). KatakataIrb's NestingParser is merged to ruby/irb (https://github.com/ruby/irb/pull/500).

Changed to an indent calculation demo gem. See IRB's implementation for more information.

## Difference from IRB's calculation
IRB calculates both of these.
- Next line's indent level
- Current line re-indented level (cursor position dependant)

This demo gem only calculates next line's indent level.
The result is not identical to IRB's one and not sufficient to make an IRB clone.

## Installation

Add this to your Gemfile
```
gem '[gem name]', github: '[repo url]'
```

## Usage

```ruby
IndentCalculatorDemo.calculate <<RUBY
def f
  (1..10).each do
    puts(
      _1,
RUBY
#=> 3

IndentCalculatorDemo.calculate <<'RUBY'
if true
  if true
    if true
      <<A
heredoc
#{
  puts(
RUBY
#=> 2
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/indent_calculator_demo.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
