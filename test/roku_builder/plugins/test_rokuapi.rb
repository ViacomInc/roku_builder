# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class RokuAPITest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(RokuAPI)
      @config, @options = build_config_options_objects(RokuAPITest, {submit: true, channel_id: "1234", api_key: "key1"}, false)
      @requests = []
    end

    def teardown
      @requests.each {|req| remove_request_stub(req)}
    end

    def test_commands
      commands = RokuAPI.commands
      refute_nil commands[:submit]
      refute_nil commands[:publish]
    end

    def test_parse_options
      parser = OptionParser.new
      options = {}
      RokuAPI.parse_options(parser: parser, options: options)
      argv = ["roku", "--submit", "--publish", "--channel-id", "1234", "--api-key", "key1"]
      parser.parse! argv
      assert options[:submit]
      assert options[:publish]
      assert_equal options[:channel_id], "1234"
      assert_equal options[:api_key], "key1"
    end

    def test_dependencies
      assert_kind_of Array, RokuAPI.dependencies
      assert_equal RokuAPI.dependencies.count, 0
    end

    def test_get_jwt_token
      api = RokuAPI.new(config: @config)
      urn = "test:urn"
      method = "GET"
      path = "/test/path"
      token = api.send(:get_jwt_token, @options[:api_key], urn, method, path)
      jwk = JWT::JWK.new(JSON.parse(File.read(@config.api_keys[:key1])))
      decoded = JWT.decode(token, jwk.public_key, true, {algorithm: 'RS256'})
      assert_equal decoded[1]["typ"], "JWT"
      assert_equal decoded[1]["alg"], "RS256"
      assert_equal decoded[1]["kid"], jwk.export[:kid]

      assert is_uuid?(decoded[0]["x-roku-request-key"])
      spec = decoded[0]["x-roku-request-spec"]
      refute_nil spec
      assert_equal spec["serviceUrn"], urn
      assert_equal spec["httpMethod"], method
      assert_equal spec["path"], path
    end

    def test_get_jwt_token_with_body
      api = RokuAPI.new(config: @config)
      urn = "test:urn"
      method = "GET"
      path = "/test/path"
      body = {
        "appFileBase64Encoded" => Base64.encode64(File.open(File.join(test_files_path(RokuAPITest), "test.pkg")).read)
      }
      sha256 = Digest::SHA256.base64digest(body.to_json)
      token = api.send(:get_jwt_token, @options[:api_key], urn, method, path, body.to_json)
      jwk = JWT::JWK.new(JSON.parse(File.read(@config.api_keys[:key1])))
      decoded = JWT.decode(token, jwk.public_key, true, {algorithm: 'RS256'})
      assert_equal decoded[1]["typ"], "JWT"
      assert_equal decoded[1]["alg"], "RS256"
      assert_equal decoded[1]["kid"], jwk.export[:kid]

      assert is_uuid?(decoded[0]["x-roku-request-key"])
      spec = decoded[0]["x-roku-request-spec"]
      refute_nil spec
      assert_equal spec["serviceUrn"], urn
      assert_equal spec["httpMethod"], method
      assert_equal spec["path"], path
      assert_equal spec["bodySha256Base64"], sha256
    end

    def test_api_get
      api = RokuAPI.new(config: @config)
      path = "/test/path"
      api.instance_variable_set(:@api_key, "key1")
      @requests.push(stub_request(:any, /apipub.roku.com.*/))
      response = api.send(:api_get, path)
      assert_requested(:get, "https://apipub.roku.com/developer/v1/test/path", headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => /Bearer .*/
      })
    end

    def test_api_post
      api = RokuAPI.new(config: @config)
      path = "/test/path"
      api.instance_variable_set(:@api_key, "key1")
      package = File.open(File.join(test_files_path(RokuAPITest), "test.pkg"))
      encoded = Base64.encode64(package.read)
      @requests.push(stub_request(:any, /apipub.roku.com.*/))
      response = api.send(:api_post, path, package)
      assert_requested(:post, "https://apipub.roku.com/developer/v1/test/path", 
                       body: {"appFileBase64Encoded" => encoded}.to_json,
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "Authorization" => /Bearer .*/
        }
      )
    end

    def test_get_channel_versions
      api = RokuAPI.new(config: @config)
      channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      response = Minitest::Mock.new
      body = { "id" => "1234", "version" => "1.1"}
      response.expect(:body, body.to_json)
      get_proc = proc do |path|
        assert_equal path, "/external/channels/#{channel}/versions"
        response
      end
      api.stub(:api_get, get_proc) do
        result = api.send(:get_channel_versions, channel)
        assert_equal result, body        
      end
    end

    def test_submit_no_channel_id
      api = RokuAPI.new(config: @config)
      assert_raises RokuBuilder::InvalidOptions do
        api.submit(options: {})
      end
    end

    def test_submit_without_unpublished
      api = RokuAPI.new(config: @config)
      called = {}
      updated = proc {called[:updated] = true}
      created = proc {called[:created] = true}
      @requests.push(stub_request(:any, "https://apipub.roku.com/developer/v1/external/channels/1234/versions").to_return(
        body: api_versions.to_json
      ))
      api.stub(:create_channel_version, created) do
        api.stub(:update_channel_version, updated) do
          api.stub(:get_package, "") do
            api.submit(options: @options)
          end
        end
      end
      assert called[:created]
      assert_nil called[:updated]
    end

    def test_submit_with_unpublished
      api = RokuAPI.new(config: @config)
      called = {}
      updated = proc {called[:updated] = true}
      created = proc {called[:created] = true}
      body = api_versions
      body[0]["channelState"] = "Unpublished"
      @requests.push(stub_request(:any, "https://apipub.roku.com/developer/v1/external/channels/1234/versions").to_return(
        body: body.to_json
      ))
      api.stub(:create_channel_version, created) do
        api.stub(:update_channel_version, updated) do
          api.stub(:get_package, "") do
            api.submit(options: @options)
          end
        end
      end
      assert called[:updated]
      assert_nil called[:created]
    end

    def test_create_channel_version
      api = RokuAPI.new(config: @config)
      channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      package = File.open(File.join(test_files_path(RokuAPITest), "test.pkg"))
      response = Minitest::Mock.new
      body = { "id" => "1234", "version" => "1.1"}
      response.expect(:body, body.to_json)
      post_proc = proc do |path, package|
        assert_equal path, "/external/channels/#{channel}/versions"
        assert_kind_of File, package
      end
      api.stub(:api_post, post_proc) do
        api.send(:create_channel_version, channel, package)
      end
    end
  end
end
