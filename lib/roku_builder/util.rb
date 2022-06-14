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
      init
    end

    private

    # Second initializer to be overwriten
    def init
      #Override in subclass
    end

    # Generates a simpe Faraday connection with digest credentials
    # @return [Faraday] The faraday connection
    def simple_connection(device: nil, no_lock: false, &block)
      raise ImplementationError, "No block given to simple_connection" unless block_given?
      get_device(device: device, no_lock: no_lock) do |device|
        url = "http://#{device.ip}"
        connection = Faraday.new(url: url) do |f|
          f.request :digest, device.user, device.password
          f.adapter Faraday.default_adapter
        end
        block.call(connection)
      end
    end

    # Generates a multipart Faraday connection with digest credentials
    # @param port [Integer] optional port to connect to
    # @return [Faraday] The faraday connection
    def multipart_connection(port: nil, device: nil, no_lock: false, &block)
      raise ImplementationError, "No block given to multipart_connection" unless block_given?
      get_device(device: device, no_lock: no_lock) do |device|
        url = "http://#{device.ip}"
        url += ":#{port}" if port
        connection = Faraday.new(url: url) do |f|
          f.headers['Content-Type'] = Faraday::Request::Multipart.mime_type
          f.request :digest, device.user, device.password
          f.request :multipart
          f.request :url_encoded
          f.adapter Faraday.default_adapter
        end
        block.call(connection)
      end
    end

    def get_device(device: nil, no_lock: false, &block)
      raise ImplementationError, "No block given to get_device" unless block_given?
      device_given = true
      unless device
        device_given = false
        device = RokuBuilder.device_manager.reserve_device(no_lock: no_lock)
      end
      begin
        block.call(device)
      ensure
        RokuBuilder.device_manager.release_device(device) unless device_given
      end
    end
  end
end
