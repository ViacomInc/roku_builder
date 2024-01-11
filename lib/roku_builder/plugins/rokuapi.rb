# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load/Unload/Build roku applications
  class RokuAPI < Util
    extend Plugin

    def init
    end

    def self.commands
      {
        submit: {source: false},
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
      parser.separator "Options:"
      parser.on("--channel-id ID", 'ID of the channel to submit to/publish') do |id|
        options[:channel_id] = id
      end
      parser.on("--api-key KEY", 'The API key to use to submit/publish') do |key|
        options[:api_key] = key
      end
    end

    def self.dependencies
      []
    end

    def submit(options:)
      raise RokuBuilder::InvalidOptions "Missing channel id" unless options[:channel_id]
      response = get_channel(options[:channel_id], options[:api_key])
    end

    def publish(options:)
    end

    private
    
    def get_channel(channel, api_key)
      path = "/external/channels/#{channel}"
      api_get(path, api_key)
    end

    def api_get(path, api_key)
      host = "https://apipub.roku.com"
      api_path = "/developer/v1"
      service_urn = "urn:roku:cloud-services:chanprovsvc"
      connection = Faraday.new(url: host) do |f|
        f.adapter Faraday.default_adapter
      end
      connection.get(api_path+path) do |request|
        request.headers["Authorization"] = "Bearer "+get_jwt_token(api_key, service_urn, "GET", path)
        request.headers["Content-Type"] = 'application/json'
        request.headers["Accept"] = 'application/json'
      end
    end

    def get_jwt_token(api_key, service_urn, method, path, body = nil)
      key_file = File.expand_path(@config.api_keys[api_key.to_sym])
      raise InvalidOptions "Missing api key" unless key_file
      jwk = JWT::JWK.new(JSON.parse(File.read(key_file)))
      header = {
        "typ" => "JWT",
        "kid" => jwk.export[:kid]
      }
      payload = {
        "exp" => (Time.now + (12*60*60)).to_i,
        "x-roku-request-key" => SecureRandom.uuid,
        "x-roku-request-spec" => {
          "serviceUrn" => service_urn,
          "httpMethod" => method,
          "path" => path,
        }
      }
      JWT.encode(payload, jwk.signing_key, 'RS256', header)
    end
  end
  RokuBuilder.register_plugin(RokuAPI)
end
