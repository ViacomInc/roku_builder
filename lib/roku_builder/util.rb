# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Super class for device utilities
  # This class defines a common initializer and allows subclasses
  # to define their own secondary initializer
  class Util

    # Common initializer of device utils
    # @param ip [String] IP address of roku device
    # @param user [String] Username for roku device
    # @param password [String] Password for roku device
    def initialize(ip:, user:, password:, logger:, init_params: nil)
      @device_config = {
        ip: ip,
        user: user,
        password: password
      }
      @roku_ip_address = ip
      @dev_username = user
      @dev_password = password
      @url = "http://#{@roku_ip_address}"
      @logger = logger
      if init_params
        init(**init_params)
      else
        init
      end
    end

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

    # Parses a string into and options hash
    # @param options [String] string of options in the format "a:b, c:d"
    # @return [Hash] Options hash generated
    def self.options_parse(options:)
      parsed = {}
      opts = options.split(/,\s*/)
      opts.each do |opt|
        opt = opt.split(":")
        key = opt.shift.to_sym
        value = opt.join(":")
        parsed[key] = value
      end
      parsed
    end
  end
end
