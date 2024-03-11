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
      parser.on("--no-publish", 'Prevent the channel from being automatically published when submitted') do
        options[:no_publish] = true
      end 
    end

    def self.dependencies
      []
    end

    def submit(options:)
      raise RokuBuilder::InvalidOptions, "Missing channel id" unless options[:channel_id]
      @logger.info "Submit to channel #{options[:channel_id]}"
      @api_key = options[:api_key]
      @no_publish = !!options[:no_publish]
      response = get_channel_versions(options[:channel_id])
      if response.first["channelState"] == "Unpublished"
        response = update_channel_version(options[:channel_id], get_package(options), response.last["id"])
      else
        response = create_channel_version(options[:channel_id], get_package(options))
      end
      raise RokuBuilder::ExecutionError, "Request failed: #{response.reason_phrase}" unless response.success?
      JSON.parse(response.body)
    end

    def publish(options:)
      raise RokuBuilder::InvalidOptions, "Missing channel id" unless options[:channel_id]
      @logger.info "Publish to channel #{options[:channel_id]}"
      @api_key = options[:api_key]
      response = get_channel_versions(options[:channel_id])
      raise RokuBuilder::ExecutionError unless response.first["channelState"] == "Unpublished"
      response = publish_channel_version(options[:channel_id], response.first["id"])
      raise RokuBuilder::ExecutionError, "Request failed: #{response.reason_phrase}" unless response.success?
      JSON.parse(response.body)
    end

    private

    def get_package(options)
      File.open(options[:in])
    end

    def api_path
      "/developer/v1"
    end

    def get_channel_versions(channel)
      path = "/external/channels/#{channel}/versions"
      response = api_get(path)
      sorted_versions(JSON.parse(response.body))
    end

    def sorted_versions(versions)
      sorted = versions.sort do |a, b|
        DateTime.parse(b["createdDate"]) <=> DateTime.parse(a["createdDate"])
      end
      sorted
    end
    
    def create_channel_version(channel, package)
      path = "/external/channels/#{channel}/versions"
      params = nil
      unless @no_publish
        params = {"state" => "Published"}
      end
      api_post(path, path, package, params)
    end

    def update_channel_version(channel, package, version)
      path = "/external/channel/#{channel}/#{version}"
      token_path = "/external/channels/#{channel}/#{version}"
      api_patch(path, token_path, package)
    end

    def publish_channel_version(channel, version)
      path = "/external/channels/#{channel}/versions/#{version}"
      token_path = "/external/channels/#{channel}/versions/#{version}/state"
      api_post(path, token_path)
    end

    def api_get(path)
      service_urn = "urn:roku:cloud-services:chanprovsvc"
      connection('GET', path, nil).get(api_path+path)
    end

    def api_post(path, token_path, package=nil, params = nil)
      body = {}.to_json
      if package
        body = {
          "appFileBase64Encoded" => Base64.encode64(package.read)
        }.to_json
      end
      connection('POST', token_path, body, params).post(api_path+path) do |request|
        if params
          request.params = params
        end if
        request.body = body
      end
    end

    def api_patch(path, token_path, package)
      body = {
        "path" => "/appFileBase64Encoded",
        "value" => Base64.encode64(package.read),
        "op" => "replace"
      }.to_json
      response = connection('PATCH', token_path, body).patch(api_path+path) do |request|
        request.body = body
      end
    end

    def connection(method, path, body, params = nil)
      service_urn = "urn:roku:cloud-services:chanprovsvc"
      connection = Faraday.new(url: HOST, headers: {
        'Authorization' => "Bearer "+get_jwt_token(@api_key, service_urn, method, path, body, params),
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
      }) do |f|
        f.adapter Faraday.default_adapter
      end
    end

    def get_jwt_token(api_key, service_urn, method, path, body = nil, params = nil)
      key_file = File.expand_path(@config.api_keys[api_key.to_sym])
      raise InvalidOptions "Missing api key" unless key_file
      jwk = JWT::JWK.new(JSON.parse(File.read(key_file)))
      path += "?" + URI.encode_www_form(params) if params
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
