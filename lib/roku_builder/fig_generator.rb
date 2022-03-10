# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder
  class FigGenerator
    def initialize
      @mode = :option
    end

    def seperator(text)
      #do nothing
    end

    def generate
      config_string = "const completionSpec: Fig.Spec = "
      config = {
        name: "roku"
      }
      config_string + config.to_json
    end

    def mode(mode)
      @mode = mode
    end

    def on(short, long, description)

    end
  end
end
