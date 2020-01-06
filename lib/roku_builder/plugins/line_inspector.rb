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
        file.readlines.each_with_index do |line, line_number|
          full_line = line.dup
          line = line.partition("'").first if file_path.end_with?(".brs")
          if file_path.end_with?(".xml")
            if in_xml_comment
              if line.gsub!(/.*-->/, "")
                in_xml_comment = false
              else
                line = ""
              end
            end
            line.gsub!(/<!--.*-->/, "")
            in_xml_comment = true if line.gsub!(/<!--.*/, "")
          end
          indent_inspector.check_line(line: full_line, number: line_number, comment: in_xml_comment) if indent_inspector
          @inspector_config.each do |line_inspector|
            line_to_check = line
            line_to_check = full_line if line_inspector[:include_comments]
            match  = nil
            if line_inspector[:case_sensitive]
              match = /#{line_inspector[:regex]}/.match(line_to_check)
            else
              match = /#{line_inspector[:regex]}/i.match(line_to_check)
            end
            if match
              unless /'.*ignore-warning/i.match(full_line)
                add_warning(inspector: line_inspector, file: file_path, line: line_number, match: match)
              end
            end
          end
        end
        @warnings += indent_inspector.warnings if indent_inspector
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
