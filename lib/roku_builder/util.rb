# ********** Copyright Viacom, Inc. Apache 2.0 **********
module RokuBuilder

  # Super class for modules
  # This class defines a common initializer and allows subclasses
  # to define their own secondary initializer
  class Util

    # Common initializer of device utils
    # @param config [Config] Configuration object for the app
    def initialize(config: )
      @logger = Logger.instance
      @config = config
      @roku_ip_address = @config.device_config[:ip]
      @dev_username = @config.device_config[:user]
      @dev_password = @config.device_config[:password]
      @url = "http://#{@roku_ip_address}"
      init
    end

    private

    # Second initializer to be overwriten
    def init
      #Override in subclass
    end

    # Generates a simpe Faraday connection with digest credentials
    # @return [Faraday] The faraday connection
    def simple_connection
      Faraday.new(url: @url) do |f|
        f.request :digest, @dev_username, @dev_password
        f.adapter Faraday.default_adapter
      end
    end

    # Generates a multipart Faraday connection with digest credentials
    # @param port [Integer] optional port to connect to
    # @return [Faraday] The faraday connection
    def multipart_connection(port: nil)
      url = @url
      url = "#{url}:#{port}" if port
      Faraday.new(url: url) do |f|
        f.headers['Content-Type'] = Faraday::Request::Multipart.mime_type
        f.request :digest, @dev_username, @dev_password
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end
  end
end
