# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load/Unload/Build roku applications
  class RokuAPI < Util
    extend Plugin

    HOST = "https://apipub.roku.com"

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
      raise RokuBuilder::InvalidOptions, "Missing channel id" unless options[:channel_id]
      @api_key = options[:api_key]
      response = get_channel_versions(options[:channel_id])
      if response.first["channelState"] == "Unpublished"
        update_channel_version(options[:channel_id], get_package(options))
      else
        create_channel_version(options[:channel_id], get_package(options))
      end
    end

    def publish(options:)
    end

    private

    def get_package(options)
      File.open(options[:in])
    end
    
    def get_channel_versions(channel)
      path = "/external/channels/#{channel}/versions"
      response = api_get(path)
      JSON.parse(response.body)
    end

    def create_channel_version(channel, package)
      path = "/external/channels/#{channel}/versions"
      api_post(path, package)
    end

    def update_channel_version(channel)
    end

    def api_get(path)
      api_path = "/developer/v1"
      service_urn = "urn:roku:cloud-services:chanprovsvc"
      connection('GET', path, nil).get(api_path+path)
    end

    def api_post(path, package)
      api_path = "/developer/v1"
      body = {
        "appFileBase64Encoded" => Base64.encode64(package.read)
      }.to_json
      response = connection('POST', path, body).post(api_path+path) do |request|
        request.body = body
      end
    end

    def connection(method, path, body)
      service_urn = "urn:roku:cloud-services:chanprovsvc"
      connection = Faraday.new(url: HOST, headers: {
        'Authorization' => "Bearer "+get_jwt_token(@api_key, service_urn, method, path, body),
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
      }) do |f|
        f.adapter Faraday.default_adapter
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
      if body
        payload["x-roku-request-spec"]["bodySha256Base64"] = Digest::SHA256.base64digest(body)
      end
      JWT.encode(payload, jwk.signing_key, 'RS256', header)
    end
  end
  RokuBuilder.register_plugin(RokuAPI)
end
