require_relative './trex'

module IndentCalculator
  def self.tokenize(code)
    Ripper::Lexer.new(code).scan.chunk(&:pos).map do |_pos, same_pos_tokens|
      same_pos_tokens.find { !_1.event.end_with?('_error') } || same_pos_tokens.first
    end
  end

  def self.calculate(code)
    opens = TRex.open_tokens tokenize(code)
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
        # ignore. `a ? b : c` and `do |param|`
      else
        indent_level += 1
      end
    end
    indent_level
  end
end
