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
      performance_config = get_config("performance_config.json")
      linter_config = get_config(".roku_builder_linter.json", true)
      linter_config ||= {}
      loader = Loader.new(config: @config)
      Dir.mktmpdir do |dir|
        loader.copy(options: options, path: dir)
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

