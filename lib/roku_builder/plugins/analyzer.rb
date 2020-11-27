# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Collects information on a package for submission
  class Analyzer < Util
    extend Plugin

    def self.commands
      {
        analyze: {source: true, stage: true},
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("--analyze", "Run a static analysis on a given stage") do
        options[:analyze] = true
      end
      parser.separator "Options:"
      parser.on("--inclide-libraries", "Include libraries in analyze") do
        options[:include_libraries] = true
      end
    end

    def self.dependencies
      [Loader]
    end

    def analyze(options:, quiet: false)
      @options = options
      @warnings = []
      @sca_warning = {}
      performance_config = get_config("performance_config.json")
      linter_config = get_config(".roku_builder_linter.json", true)
      linter_config ||= {is_ssai: false}
      loader = Loader.new(config: @config)
      Dir.mktmpdir do |dir|
        loader.copy(options: options, path: dir)
        run_sca_tool(path: dir, ssai: linter_config[:is_ssai])
        libraries = @config.project[:libraries]
        libraries ||= []
        Dir.glob(File.join(dir, "**", "*")).each do |file_path|
          file = file_path.dup; file.slice!(dir)
          unless libraries.any_is_start?(file) and not @options[:include_libraries]
            if File.file?(file_path) and file_path.end_with?(".brs", ".xml")
              line_inspector_config = performance_config
              line_inspector_config += linter_config[:rules] if linter_config[:rules]
              line_inspector = LineInspector.new(inspector_config: line_inspector_config, indent_config: linter_config[:indentation])
              @warnings.concat(line_inspector.run(file_path))
            end
          end
        end
        format_messages(dir)
        print_warnings unless quiet
      end
      @warnings
    end

    private

    def run_sca_tool(path:, ssai:)
      if OS.unix?
         command = File.join(File.dirname(__FILE__), "sca-cmd", "bin", "sca-cmd")
      else
        command = File.join(File.dirname(__FILE__), "sca-cmd", "bin", "sca-cmd.bat")
      end
      results = `#{command} #{path}`.split("\n")
      process_sca_results(results, ssai)
    end

    def process_sca_results(results, ssai)
      results.each do |result_line|
        if /-----+/.match(result_line) or /\*\*\*\*\*+/.match(result_line)
          @warnings.push(@sca_warning) if add_warning?(ssai)
          @sca_warning = {}
        elsif data = /^(\[WARNING\]|\[INFO\]|\[ERROR\])(.*)$/.match(result_line)
          @warnings.push(@sca_warning) if add_warning?(ssai)
          @sca_warning = {}
          @sca_warning[:severity] = data[1].gsub(/(\[|\])/, "").downcase
          @sca_warning[:message] = data[2]
        elsif data = /^\sPath: ([^ ]*) Line: (\d*)./.match(result_line)
          @sca_warning[:path] = data[1]+":"+data[2]
        elsif @sca_warning and  @sca_warning[:message]
          @sca_warning[:message] += " " + result_line
        end
      end
    end

    def add_warning?(ssai)
      if @sca_warning and @sca_warning[:severity]
        if ssai and /SetAdUrl\(\) method is missing/.match(@sca_warning[:message])
          return false
        end
        return true
      end
      return false
    end

    def get_config(file, project_root=false)
      if project_root
        file = File.join(@config.root_dir, file)
      else
        file = File.join(File.dirname(__FILE__), file)
      end
      JSON.parse(File.open(file).read, {symbolize_names: true}) if File.exist? file
    end

    def print_warnings
      logger = ::Logger.new(STDOUT)
      logger.level  = @logger.level
      logger.formatter = proc {|severity, _datetime, _progname, msg|
        "%5s: %s\n\r" % [severity, msg]
      }
      @logger.unknown "====== Analysis Results ======"
      @warnings.each do |warning|
        message = warning[:message]
        case(warning[:severity])
        when "error"
          logger.error(message)
        when "warning"
          logger.warn(message)
        when "info"
          logger.info(message)
        end
      end
    end

    def format_messages(dir)
      @warnings.each do |warning|
        if warning[:path]
          warning[:path].slice!(dir) if dir
          warning[:path].slice!(/^\//)
          warning[:message] += ". pkg:/"+warning[:path]
          warning[:message] += ":"+(warning[:line]+1).to_s if warning[:line]
        end
      end
    end
  end
  RokuBuilder.register_plugin(Analyzer)
end

