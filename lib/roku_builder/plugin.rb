# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Super class for modules
  # This class defines a common initializer and allows subclasses
  # to define their own secondary initializer
  module Plugin

    def commands
      raise ImplementationError, "commands method not implemented in #{self}"
      #[
      #  {
      #   name: :command_name,
      #   device: true || false,
      #   source: true || false,
      #   exclude: true || false
      #  }
      #]
    end

    def parse_options(option_parser:, options:)
      raise ImplementationError, "parse_options method not implemented"
    end

    def dependencies
      []
    end
  end
end
