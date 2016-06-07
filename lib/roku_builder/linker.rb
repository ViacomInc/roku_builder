# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Launch application, sending parameters
  class Linker < Util
    # Deeplink to an app
    # @param options [String] Options string
    # @param app_id [String] Id of the app to launch (defaults to dev)
    # @param logger [Logger] System Logger
    # @note Options string should be formated like the following: "<key>:<value>[, <key>:<value>]*"
    # @note Any options will be accepted and sent to the app
    def launch(options: nil, app_id: "dev")
      path = "/launch/#{app_id}"
      payload = Util.options_parse(options: options)

      unless payload.keys.count > 0
        @logger.warn "No options sent to launched app"
      else
        path = "#{path}?#{parameterize(payload)}"
      end

      conn = multipart_connection(port: 8060)

      response = conn.post path
      return response.success?
    end

    # List currently installed apps
    # @param logger [Logger] System Logger
    def list()
      path = "/query/apps"
      conn = multipart_connection(port: 8060)
      response = conn.get path

      if response.success?
        regexp = /id="([^"]*)"\stype="([^"]*)"\sversion="([^"]*)">([^<]*)</
        apps = response.body.scan(regexp)
        printf("%30s | %10s | %10s | %10s\n", "title", "id", "type", "version")
        printf("---------------------------------------------------------------------\n")
        apps.each do |app|
          printf("%30s | %10s | %10s | %10s\n", app[3], app[0], app[1], app[2])
        end
      end
    end

    private

    # Parameterize options to be sent to the app
    # @param params [Hash] Parameters to be sent
    # @return [String] Parameters as a string, URI escaped
    def parameterize(params)
      params.collect{|k,v| "#{k}=#{CGI.escape(v)}"}.join('&')
    end
  end
end
