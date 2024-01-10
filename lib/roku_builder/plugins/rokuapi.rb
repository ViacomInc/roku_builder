# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load/Unload/Build roku applications
  class RokuAPI < Util
    extend Plugin

    def init
    end

    def self.commands
      {
        submit: {source: true},
        publish: {}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("--submit", 'Submit a package to the Roku Portal') do
        options[:submit] = true
      end
      parser.on("--publish", 'Publish an app on the Roku Portal') do
        options[:publish] = true
      end
    end

    def self.dependencies
      []
    end

    def submit(options:)
    end

    def publish(options:)
    end
  end
end
