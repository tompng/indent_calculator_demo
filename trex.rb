module NestingParser
  IGNORE_TOKENS = %i[on_sp on_ignored_nl on_comment on_embdoc_beg on_embdoc on_embdoc_end]

  # Scan each token and call the given block with array of token and other information for parsing
  def self.scan_opens(tokens)
    opens = []
    pending_heredocs = []
    first_token_on_line = true
    tokens.each do |t|
      skip = false
      last_tok, state, args = opens.last
      case state
      when :in_unquoted_symbol
        unless IGNORE_TOKENS.include?(t.event)
          opens.pop
          skip = true
        end
      when :in_lambda_head
        opens.pop if t.event == :on_tlambeg || (t.event == :on_kw && t.tok == 'do')
      when :in_method_head
        unless IGNORE_TOKENS.include?(t.event)
          next_args = []
          body = nil
          if args.include?(:receiver)
            case t.event
            when :on_lparen, :on_ivar, :on_gvar, :on_cvar
              # def (receiver). | def @ivar. | def $gvar. | def @@cvar.
              next_args << :dot
            when :on_kw
              case t.tok
              when 'self', 'true', 'false', 'nil'
                # def self(arg) | def self.
                next_args.push(:arg, :dot)
              else
                # def if(arg)
                skip = true
                next_args << :arg
              end
            when :on_op, :on_backtick
              # def +(arg)
              skip = true
              next_args << :arg
            when :on_ident, :on_const
              # def a(arg) | def a.
              next_args.push(:arg, :dot)
            end
          end
          if args.include?(:dot)
            # def receiver.name
            next_args << :name if t.event == :on_period || (t.event == :on_op && t.tok == '::')
          end
          if args.include?(:name)
            if %i[on_ident on_const on_op on_kw on_backtick].include?(t.event)
              # def name(arg) | def receiver.name(arg)
              next_args << :arg
              skip = true
            end
          end
          if args.include?(:arg)
            case t.event
            when :on_nl, :on_semicolon
              # def recever.f;
              body = :normal
            when :on_lparen
              # def recever.f()
              next_args << :eq
            else
              if t.event == :on_op && t.tok == '='
                # def receiver.f =
                body = :oneliner
              else
                # def recever.f arg
                next_args << :arg_without_paren
              end
            end
          end
          if args.include?(:eq)
            if t.event == :on_op && t.tok == '='
              body = :oneliner
            else
              body = :normal
            end
          end
          if args.include?(:arg_without_paren)
            if %i[on_semicolon on_nl].include?(t.event)
              # def f a;
              body = :normal
            else
              # def f a, b
              next_args << :arg_without_paren
            end
          end
          if body == :oneliner
            opens.pop
          elsif body
            opens[-1] = [last_tok, nil]
          else
            opens[-1] = [last_tok, :in_method_head, next_args]
          end
        end
      when :in_for_while_until_condition
        if t.event == :on_semicolon || t.event == :on_nl || (t.event == :on_kw && t.tok == 'do')
          skip = true if t.event == :on_kw && t.tok == 'do'
          opens[-1] = [last_tok, nil]
        end
      when :in_block_head
        if t.event == :on_op && t.tok == '|'
          opens[-1] = [last_tok, nil]
          opens << [t, :in_block_args]
        elsif !IGNORE_TOKENS.include?(t.event)
          opens[-1] = [last_tok, nil]
        end
      when :in_block_args
        if t.event == :on_op && t.tok == '|' && t.state.allbits?(Ripper::EXPR_BEG)
          opens.pop
          skip = true
        end
      end

      unless skip
        case t.event
        when :on_kw
          case t.tok
          when 'do'
            opens << [t, :in_block_head]
          when 'begin', 'class', 'module', 'case'
            opens << [t, nil]
          when 'end'
            opens.pop
          when 'def'
            opens << [t, :in_method_head, [:receiver, :name]]
          when 'if', 'unless'
            unless t.state.allbits?(Ripper::EXPR_LABEL)
              opens << [t, nil]
            end
          when 'while', 'until'
            unless t.state.allbits?(Ripper::EXPR_LABEL)
              opens << [t, :in_for_while_until_condition]
            end
          when 'ensure', 'rescue'
            unless t.state.allbits?(Ripper::EXPR_LABEL)
              opens.pop
              opens << [t, nil]
            end
          when 'elsif', 'else', 'when'
            opens.pop
            opens << [t, nil]
          when 'for'
            opens << [t, :in_for_while_until_condition]
          when 'in'
            if last_tok&.event == :on_kw && %w[case in].include?(last_tok.tok) && first_token_on_line
              opens.pop
              opens << [t, nil]
            end
          end
        when :on_lbrace
          if t.state.allbits?(Ripper::EXPR_LABEL)
            opens << [t, nil]
          else
            opens << [t, :in_block_head]
          end
        when :on_tlambda
          opens << [t, :in_lambda_head]
        when :on_lparen, :on_lbracket, :on_tlambeg, :on_embexpr_beg, :on_embdoc_beg
          opens << [t, nil]
        when :on_rparen, :on_rbracket, :on_rbrace, :on_embexpr_end, :on_embdoc_end
          opens.pop
        when :on_heredoc_beg
          pending_heredocs << t
        when :on_heredoc_end
          opens.pop
        when :on_backtick
          opens << [t, nil] if t.state.allbits?(Ripper::EXPR_BEG)
        when :on_tstring_beg, :on_words_beg, :on_qwords_beg, :on_symbols_beg, :on_qsymbols_beg, :on_regexp_beg
          opens << [t, nil]
        when :on_tstring_end, :on_regexp_end, :on_label_end
          opens.pop
        when :on_symbeg
          if t.tok == ':'
            opens << [t, :in_unquoted_symbol]
          else
            opens << [t, nil]
          end
        when :on_op
          case t.tok
          when '?'
            # opening of `cond ? value : value``
            opens << [t, nil]
          when ':'
            # closing of `cond ? value : value``
            opens.pop
          end
        end
      end
      if t.event == :on_nl || t.event == :on_semicolon
        first_token_on_line = true
      elsif t.event != :on_sp
        first_token_on_line = false
      end
      if pending_heredocs.any? && t.tok.include?("\n")
        pending_heredocs.reverse_each { |t| opens << [t, nil] }
        pending_heredocs = []
      end
      yield t, opens if block_given?
    end
    opens.map(&:first) + pending_heredocs.reverse
  end

  def self.open_tokens(tokens)
    # scan_opens without block will return a list of open tokens at last token position
    scan_opens(tokens)
  end
end
