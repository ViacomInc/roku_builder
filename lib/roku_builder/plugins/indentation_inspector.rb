# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder
  class IndentationInspector
    attr_reader :warnings
    def initialize(rules:, path:)
      @character = get_character(rules[:character])
      @count = rules[:count].to_i
      @path = path
      @type = File.extname(path)[1..-1].to_sym
      @warnings = []
      @prev_line = nil
      @ind = 0
    end

    def check_line(line:, number:, comment:)
      #byebug if number == 10 and @path.ends_with?(".brs")
      set_indentation(line: line)
      regexp = /^#{@character}{#{@ind}}[^#{@character}]/
      unless line =~ regexp or line == "\n" or line =~ /\'indent-ignore/ or comment
        add_warning(line: number)
      end
      @prev_line = line
    end

    def set_indentation(line:)
      case @type
      when :xml
        if @prev_line and @prev_line =~ /<[^?!\/][^>]*[^\/]>/
          unless @prev_line =~ /<([^>\/]*)>.*<\/\1*>/
            @ind += @count
          end
        end
        if line =~ /<\/[^>]*>/
          unless line =~ /<([^>\/]*)>.*<\/\1*>/
            @ind -= @count
          end
        end
      when :brs
        if line =~ /'indent-reset/
          @ind = line.index(/[^#{@character}]/)
        else
          if @prev_line
            if @prev_line =~ /^\'/ or @prev_line =~ /\'indent-ignore/
              # Don't change indentation
            elsif @prev_line =~ /[\{\[\(:]$/
              @ind += @count
            elsif @prev_line =~ /:\s*\bfunction\b|:\s*\bsub\b/i
              @ind += @count
            elsif @prev_line =~ /^\s*\bfunction\b|^\s*\bsub\b/i
              @ind += @count
            elsif @prev_line =~ /^\s*#?if\b|^\s*#?else\b/i
              unless @prev_line =~ /\bthen\b[ \t ]*[^' \r\n']+.*$/i or @prev_line =~ /\breturn\b/i
                @ind += @count
              end
            elsif @prev_line =~ /^\s*\bfor\b|^\s*\bwhile\b/i
              @ind += @count
            end
          end
          if line =~ /^\'/ or line =~ /\'indent-ignore/
            # Don't change indentation
          elsif line =~ /^\s*[\}\]\)]/
            @ind -= @count
          elsif line =~ /^\s*\bfunction\b|^\s*\bsub\b/i
            @ind -= 0
          elsif line =~ /^\s*:?\s*#?end\b|^\s*#?endif\b|^\s*endfor\b|^\s*\bnext\b/i
            @ind -= @count
          elsif line =~ /^\s*#?else\b|^\s*elseif\b/i
            @ind -= @count
          end
        end
      end
    end

    private

    def get_character(character)
      case character
      when "tab"
        "\t"
      when "space"
        " "
      end
    end

    def add_warning(line:)
      @warnings.push({severity: "warning", message: 'Incorrect indentation'})
      @warnings.last[:path] = @path
      @warnings.last[:line] = line
    end
  end
end

