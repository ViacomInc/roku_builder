# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Launch application, sending parameters
  class Linker < Util
    extend Plugin

    def self.commands
      {
        deeplink: {device: true, stage: true},
        input: {device: true},
        applist: {device: true}
      }
    end

    def self.parse_options(parser:,  options:)
      parser.separator "Commands:"
      parser.on("-o", "--deeplink OPTIONS", "Launch and Deeplink into app. Define options as keypairs (eg. \"a:b, c:d,e:f\") or name (eg. \"name\"). To use named deeplinks, including them in your config file: \"deeplinks\": { \"name\": \"a:b, c:d, e:f\" }") do |o|
        options[:deeplink] = o
      end
      parser.on("-i", "--input OPTIONS", "Deeplink into app. Define options as keypairs (eg. \"a:b, c:d,e:f\") or name (eg. \"name\"). To use named deeplinks, including them in your config file: \"deeplinks\": { \"name\": \"a:b, c:d, e:f\" }") do |o|
        options[:input] = o
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
    def deeplink(options:, device: nil)
      get_device(device: device) do |device|
        if options.has_source?
          Loader.new(config: @config).sideload(options: options, device: device)
        end
        app_id = options[:app_id]
        app_id ||= "dev"
        path = "/launch/#{app_id}"
        send_options(path: path, options: options[:deeplink], device: device)
      end
    end

    def input(options:)
      send_options(path: "/input", options: options[:input])
    end

    # List currently installed apps
    # @param logger [Logger] System Logger
    def applist(options:)
      path = "/query/apps"
      response = nil
      multipart_connection(port: 8060) do |conn|
        response = conn.get path
      end

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

    def send_options(path:, options:, device: nil)
      payload = RokuBuilder.options_parse(options: options)
      get_device(device: device) do |device|
        unless payload.keys.count > 0
          @logger.warn "No options sent to launched app"
        else
          deeplinks = @config.deeplinks
          firstKey = payload.keys.first
          if !deeplinks.nil?
            if !deeplinks[firstKey].nil?
              payload = RokuBuilder.options_parse(options: deeplinks[firstKey])
            end
          end
          payload = parameterize(payload)
          path = "#{path}?#{payload}"
            @logger.info "Deeplink:"
          @logger.info payload
          @logger.info "CURL:"
          @logger.info "curl -d '' 'http://#{device.ip}:8060#{path}'"
        end

        multipart_connection(port: 8060, device: device) do |conn|
          response = conn.post path
          @logger.fatal("Failed Deeplinking") unless response.success?
        end
      end
    end

    # Parameterize options to be sent to the app
    # @param params [Hash] Parameters to be sent
    # @return [String] Parameters as a string, URI escaped
    def parameterize(params)
      params.collect{|k,v| "#{k}=#{CGI.escape(v)}"}.join('&')
    end
  end
  RokuBuilder.register_plugin(Linker)
end
