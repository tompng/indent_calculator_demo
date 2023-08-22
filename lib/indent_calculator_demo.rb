require_relative 'indent_calculator_demo/version'
require_relative 'indent_calculator_demo/nesting_parser'

module IndentCalculatorDemo
  def self.tokenize(code)
    tokens = Ripper::Lexer.new(code).scan.chunk(&:pos).map do |_pos, same_pos_tokens|
      same_pos_tokens.find { !_1.event.end_with?('_error') } || same_pos_tokens.first
    end
    interpolate_missing_tokens code, tokens
  end

  # Workaround for https://bugs.ruby-lang.org/issues/19736 and other similar behavior
  def self.interpolate_missing_tokens(code, tokens)
    bytepos_by_line = [0]
    code.lines.each { bytepos_by_line << bytepos_by_line.last + _1.bytesize }
    prev_token_end_pos = 0
    interpolated = []
    tokens.each do |token|
      token_start_pos = bytepos_by_line[token.pos[0] - 1] + token.pos[1]
      if prev_token_end_pos < token_start_pos
        interpolated << Ripper::Lexer::Elem.new([0, 0], :on_ignored_by_ripper, code.byteslice(prev_token_end_pos...token_start_pos), 0)
      end
      interpolated << token
      prev_token_end_pos = token_start_pos + token.tok.bytesize
    end
    interpolated
  end

  def self.calculate(code)
    opens = NestingParser.open_tokens tokenize(code)
    indent_level = 0
    opens.each do |token|
      case token.event
      when :on_heredoc_beg
        if token.tok.match?(/\A<<[~-]/)
          indent_level += 1
        else
          indent_level = 0
        end
      when :on_tstring_beg, :on_regexp_beg
        indent_level += 1 if token.tok[0] == '%'
      when :on_embdoc_beg
        indent_level = 0
      when :on_op
        # ignore nesting of `a ? b : c` and `|block_parameter|`
      else
        indent_level += 1
      end
    end
    indent_level
  end
end
