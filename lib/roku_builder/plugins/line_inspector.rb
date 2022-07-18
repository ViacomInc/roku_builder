# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class LineInspector
    def initialize(inspector_config:, indent_config:)
      @inspector_config = inspector_config
      @indent_config = indent_config
    end

    def run(file_path)
      @warnings = []
      File.open(file_path) do |file|
        in_xml_comment = false
        indent_inspector = IndentationInspector.new(rules: @indent_config, path: file_path) if @indent_config
        full_file = []
        file_no_comments = []
        lines_to_ignore = []
        file.readlines.each_with_index do |line, line_number|
          full_line = line.dup
          line.gsub!(/'.*/, "") if file_path.end_with?(".brs")
          if file_path.end_with?(".xml")
            if in_xml_comment
              if line.gsub!(/.*-->/, "")
                in_xml_comment = false
              else
                line = "\n"
              end
            end
            line.gsub!(/<!--.*-->/, "")
            in_xml_comment = true if line.gsub!(/<!--.*/, "")
          end
          indent_inspector.check_line(line: full_line, number: line_number, comment: in_xml_comment) if indent_inspector
          if  /'.*ignore-warning/i.match(full_line)
            lines_to_ignore.push line_number
          end
          full_file.push(full_line)
          file_no_comments.push(line)
        end
        @warnings += indent_inspector.warnings if indent_inspector
        no_comments = file_no_comments.join("")
        file = full_file.join("")
        @inspector_config.each do |line_inspector|
          unless line_inspector[:disabled]
            to_check = no_comments
            to_check = file if line_inspector[:include_comments]
            match  = nil
            start = 0
            loop do
              stop = to_check.length-1
              pass_match = nil
              if line_inspector[:pass_if_match]
                if line_inspector[:case_sensitive]
                  pass_match = /#{line_inspector[:pass_test_regexp]}/.match(to_check[start..stop])
                else
                  pass_match = /#{line_inspector[:pass_test_regexp]}/i.match(to_check[start..stop])
                end
                break unless pass_match
                stop = to_check.index("\n", start)
                stop ||= to_check.length-1
              end
              if line_inspector[:case_sensitive]
                match = /#{line_inspector[:regex]}/.match(to_check[start..stop])
              else
                match = /#{line_inspector[:regex]}/i.match(to_check[start..stop])
              end
              if (not line_inspector[:pass_if_match] and match) or (line_inspector[:pass_if_match] and not match)
                error_match = match
                if match
                  start = match.end(0)
                  line_number = to_check[0..match.begin(0)].split("\n", -1).count - 1
                else
                  error_match = pass_match
                  line_number = to_check[0..start].split("\n", -1).count - 1
                  start = stop
                end
                unless lines_to_ignore.include?(line_number)
                  add_warning(inspector: line_inspector, file: file_path, line: line_number, match: error_match)
                end
              elsif line_inspector[:pass_if_match]
                start = stop +1
              else
                break
              end
            end
          end
        end
      end
      @warnings
    end

    private

    def add_warning(inspector:,  file:, line:, match: )
      @warnings.push(inspector.deep_dup)
      @warnings.last[:path] = file
      @warnings.last[:line] = line
      @warnings.last[:match] = match
    end
  end
end
