# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class DeviceManager

    def initialize(options:, config:)
      @config = config
      @options = options
    end

    def reserve_device
      message = "No Devices Found"
      if @options[:device_given]
        device = Device.new(@options[:device], @config.raw[:devices][@options[:device].to_sym])
        return device if device_avaiable!(device)
        message = "Device #{@options[:device]} not found"
      else
        device = reserve_any
        return device if device
      end
      raise DeviceError, message
    end

    def release_device(device)
      lock = lock_file(device)
      File.delete(lock) if File.exist?(lock)
    end

    private

    def reserve_any
      default = @config.raw[:devices][:default]
      all_devices = @config.raw[:devices].keys.reject{|key, value| [:default, default].include?(key)}
      all_devices.unshift(default)
      all_devices.each do |device_name|
        device = Device.new(device_name, @config.raw[:devices][device_name])
        if device_avaiable!(device)
          return device
        end
      end
      nil
    end

    def device_avaiable!(device)
      return false unless device_ping?(device)
      lock = lock_file(device).flock(File::LOCK_EX|File::LOCK_NB)
      return false if lock == false
      true
    end

    def device_ping?(device)
      ping = Net::Ping::External.new
      ping.ping? device.ip, 1, 0.2, 1
    end

    def lock_file(device)
      File.open(File.join(Dir.tmpdir, device.name), "w+")
    end

  end

  class Device
    attr_accessor :name, :ip, :user, :password

    def initialize(name, device_config)
      @name = name.to_s
      @ip = device_config[:ip]
      @user = device_config[:user]
      @password = device_config[:password]
    end
  end
end
