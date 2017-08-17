# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Launch application, sending parameters
  class Linker < Util
    extend Plugin

    def self.commands
      {
        deeplink: {device: true, stage: true},
        applist: {device: true}
      }
    end

    def self.parse_options(parser:,  options:)
      parser.separator "Commands:"
      parser.on("-o", "--deeplink OPTIONS", "Deeplink into app. Define options as keypairs. (eg. a:b, c:d,e:f)") do |o|
        options[:deeplink] = o
      end
      parser.on("-A", "--app-list", "List currently installed apps") do
        options[:applist] = true
      end
      parser.separator "Options:"
      parser.on("-a", "--app ID", "Send App id for deeplinking") do |a|
        options[:app_id] = a
      end
    end

    def self.dependencies
      [Loader]
    end

    # Deeplink to an app
    def deeplink(options:)
      if options.has_source?
        Loader.new(config: @config).sideload(options: options)
      end
      app_id = options[:app_id]
      app_id ||= "dev"
      path = "/launch/#{app_id}"
      payload = RokuBuilder.options_parse(options: options[:deeplink])

      unless payload.keys.count > 0
        @logger.warn "No options sent to launched app"
      else
        payload = parameterize(payload)
        path = "#{path}?#{payload}"
        @logger.info "Deeplink:"
        @logger.info payload
        @logger.info "CURL:"
        @logger.info "curl -d '' '#{@url}:8060#{path}'"
      end

      response = multipart_connection(port: 8060).post path
      @logger.fatal("Failed Deeplinking") unless response.success?
    end

    # List currently installed apps
    # @param logger [Logger] System Logger
    def applist(options:)
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
  RokuBuilder.register_plugin(Linker)
end
