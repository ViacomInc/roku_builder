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
      WebMock.reset!
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
      argv = ["roku", "--submit", "--publish", "--channel-id", "1234", "--api-key", "key1", "--no-publish"]
      parser.parse! argv
      assert options[:submit]
      assert options[:publish]
      assert_equal options[:channel_id], "1234"
      assert_equal options[:api_key], "key1"
      assert options[:no_publish]
    end

    def test_dependencies
      assert_kind_of Array, RokuAPI.dependencies
      assert_equal RokuAPI.dependencies.count, 0
    end

    def test_get_package
      api = RokuAPI.new(config: @config)
      options = {in: "in/path"}
      called = false
      open_proc = proc do |path|
        called = true
        assert_equal options[:in], path
      end
      File.stub(:open, open_proc) do
        api.send(:get_package, options)
      end
      assert called
    end

    def test_api_path
      api = RokuAPI.new(config: @config)
      assert_equal "/developer/v1", api.send(:api_path)
    end

    def test_sorted_versions
      api = RokuAPI.new(config: @config)
      versions = [{"version" => "1.0"}, {"version" => "1.1"}, {"version" => "2.1"}]
      sorted = api.send(:sorted_versions, versions)
      assert_equal "2.1", sorted[0]["version"]
      assert_equal "1.1", sorted[1]["version"]
      assert_equal "1.0", sorted[2]["version"]
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
      token_path = "/other/path"
      api.instance_variable_set(:@api_key, "key1")
      package = File.open(File.join(test_files_path(RokuAPITest), "test.pkg"))
      encoded = Base64.encode64(package.read)
      @requests.push(stub_request(:any, /apipub.roku.com.*/))
      called = false
      jwt_proc = proc do |api_key, service_urn, method, path, body|
        called = true
        assert_equal path, token_path
        "token"
      end
      params = {"status" => "Published"}
      api.stub(:get_jwt_token, jwt_proc) do 
        response = api.send(:api_post, path, token_path, package, params)
      end
      assert called
      assert_requested(:post, "https://apipub.roku.com/developer/v1/test/path", 
                       body: {"appFileBase64Encoded" => encoded}.to_json,
                       headers: {
                         "Accept" => "application/json",
                         "Content-Type" => "application/json",
                         "Authorization" => /Bearer token/
                       },
                       query: {"status" => "Published"}
                      )
    end

    def test_api_post_no_package
      api = RokuAPI.new(config: @config)
      path = "/test/path"
      token_path = "/other/path"
      api.instance_variable_set(:@api_key, "key1")
      @requests.push(stub_request(:any, /apipub.roku.com.*/))
      called = false
      jwt_proc = proc do |api_key, service_urn, method, path, body|
        called = true
        assert_equal path, token_path
        "token"
      end
      api.stub(:get_jwt_token, jwt_proc) do 
        response = api.send(:api_post, path, token_path)
      end
      assert called
      assert_requested(:post, "https://apipub.roku.com/developer/v1/test/path", 
                       headers: {
                         "Accept" => "application/json",
                         "Content-Type" => "application/json",
                         "Authorization" => /Bearer .*/
                       }
                      )
    end

    def test_api_patch
      api = RokuAPI.new(config: @config)
      path = "/test/path"
      token_path = "/other/path"
      api.instance_variable_set(:@api_key, "key1")
      package = File.open(File.join(test_files_path(RokuAPITest), "test.pkg"))
      encoded = Base64.encode64(package.read)
      @requests.push(stub_request(:any, /apipub.roku.com.*/))
      called = false
      jwt_proc = proc do |api_key, service_urn, method, path, body|
        called = true
        assert_equal path, token_path
        "token"
      end
      api.stub(:get_jwt_token, jwt_proc) do 
        response = api.send(:api_patch, path, token_path, package)
      end
      assert called
      assert_requested(:patch, "https://apipub.roku.com/developer/v1/test/path", 
                       body: {"path" => "/appFileBase64Encoded", "value" => encoded, "op" => "replace"}.to_json,
                       headers: {
                         "Accept" => "application/json",
                         "Content-Type" => "application/json",
                         "Authorization" => /Bearer token/
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
      called = 0
      get_proc = proc do |path|
        called +=1
        assert_equal path, "/external/channels/#{channel}/versions"
        response
      end
      sort_proc = proc do |versions|
        called += 1
        versions
      end
      api.stub(:api_get, get_proc) do
        api.stub(:sorted_versions, sort_proc) do
          result = api.send(:get_channel_versions, channel)
          assert_equal result, body
        end
      end
      assert_equal 2, called
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
      @options[:no_publish] = true
      response = Minitest::Mock.new
      response.expect(:success?, true)
      updated = proc {called[:updated] = true; response}
      created = proc {called[:created] = true; response}
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
      assert api.instance_variable_get(:@no_publish)

    end
    def test_submit_without_latest_unpublished
      api = RokuAPI.new(config: @config)
      called = {}
      body = api_versions
      body.push(api_versions.first)
      body[1]["version"] = "1.3"
      body[1]["channelState"] = "Unpublished"
      response = Minitest::Mock.new
      response.expect(:success?, true)
      updated = proc {called[:updated] = true; response}
      created = proc {called[:created] = true; response}
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
      assert called[:created]
      assert_nil called[:updated]
    end

    def test_submit_with_unpublished
      api = RokuAPI.new(config: @config)
      body = api_versions
      body[0]["channelState"] = "Unpublished"
      called = {}
      response = Minitest::Mock.new
      response.expect(:success?, true)
      updated = proc do |channel, package, version|
        called[:updated] = true
        assert_equal body[0]["id"], version
        response
      end
      created = proc {called[:created] = true; response}
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
      called = false
      post_proc = proc do |path, token_path, package, params|
        called = true
        assert_equal path, "/external/channels/#{channel}/versions"
        assert_equal token_path, "/external/channels/#{channel}/versions"
        assert_equal "Published", params["channelState"]
        assert_kind_of File, package
      end
      api.stub(:api_post, post_proc) do
        api.send(:create_channel_version, channel, package)
      end
      assert called
    end

    def test_create_channel_version_no_publish
      api = RokuAPI.new(config: @config)
      channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      api.instance_variable_set(:@no_publish, true)
      package = File.open(File.join(test_files_path(RokuAPITest), "test.pkg"))
      called = false
      post_proc = proc do |path, token_path, package, params|
        called = true
        assert_equal path, "/external/channels/#{channel}/versions"
        assert_equal token_path, "/external/channels/#{channel}/versions"
        assert_nil params
        assert_kind_of File, package
      end
      api.stub(:api_post, post_proc) do
        api.send(:create_channel_version, channel, package)
      end
      assert called
    end

    def test_update_channel_version
      api = RokuAPI.new(config: @config)
      channel = "1234"
      version = "1234"
      api.instance_variable_set(:@api_key, "key1")
      package = File.open(File.join(test_files_path(RokuAPITest), "test.pkg"))
      called = false
      patch_proc = proc do |path, token_path, package|
        called = true
        assert_equal path, "/external/channel/#{channel}/#{version}"
        assert_equal token_path, "/external/channels/#{channel}/#{version}"
        assert_kind_of File, package
      end
      api.stub(:api_patch, patch_proc) do
        api.send(:update_channel_version, channel, package, version)
      end
      assert called
    end

    def test_publish_no_channel_id
      api = RokuAPI.new(config: @config)
      assert_raises RokuBuilder::InvalidOptions do
        params = {options: {}}
        api.send(:publish, **params)
      end
    end

    def test_publish_without_unpublished
      api = RokuAPI.new(config: @config)
      expected_channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      body = api_versions
      called = false
      get_proc = proc do |channel|
        called = true
        assert_equal expected_channel, channel
        body
      end
      api.stub(:get_channel_versions, get_proc) do
        assert_raises RokuBuilder::ExecutionError do
          params = {options: {channel_id: expected_channel}}
          api.send(:publish, **params)
        end
      end
      assert called
    end

    def test_publish_without_latest_unpublished
      api = RokuAPI.new(config: @config)
      expected_channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      body = api_versions
      body.push(api_versions.first)
      body[1]["version"] = "1.3"
      body[1]["channelState"] = "Unpublished"
      called = false
      get_proc = proc do |channel|
        called = true
        assert_equal expected_channel, channel
        body
      end
      api.stub(:get_channel_versions, get_proc) do
        assert_raises RokuBuilder::ExecutionError do
          params = {options: {channel_id: expected_channel}}
          api.send(:publish, **params)
        end
      end
      assert called
    end

    def test_publish_with_unpublished
      api = RokuAPI.new(config: @config)
      expected_channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      body = [{ "id" => "1234", "version" => "1.1", "channelState" => "Unpublished"}]
      called = 0
      get_proc = proc do |channel|
        called += 1
        assert_equal expected_channel, channel
        body
      end
      response = Minitest::Mock.new
      response.expect(:success?, true)
      post_proc = proc do |channel, version|
        called += 1
        assert_equal expected_channel, channel
        assert_equal body.first["id"], version
        response
      end
      api.stub(:get_channel_versions, get_proc) do
        api.stub(:publish_channel_version, post_proc) do
          params = {options: {channel_id: expected_channel}}
          api.send(:publish, **params)
        end
      end
      assert_equal called, 2
    end

    def test_publish_channel_version
      api = RokuAPI.new(config: @config)
      channel = "1234"
      api.instance_variable_set(:@api_key, "key1")
      response = Minitest::Mock.new
      body = { "id" => "1234", "version" => "1.1"}
      response.expect(:body, body.to_json)
      called = false
      post_proc = proc do |path, token_path|
        called = true
        assert_equal path, "/external/channels/#{channel}/versions/#{body["id"]}"
        assert_equal token_path, "/external/channels/#{channel}/versions/#{body["id"]}/state"
      end
      api.stub(:api_post, post_proc) do
        api.send(:publish_channel_version, channel, body["id"])
      end
      assert called
    end

    def test_submit_failure_create
      api = RokuAPI.new(config: @config)
      response = Minitest::Mock.new
      response.expect(:success?, false)
      response.expect(:reason_phrase, "reason")
      api.stub(:get_channel_versions, api_versions) do 
        api.stub(:create_channel_version, response) do
          api.stub(:get_package, "") do
            assert_raises RokuBuilder::ExecutionError do
              api.submit(options: @options)
            end 
          end 
        end 
      end 
      assert_mock response
    end

    def test_submit_response_created
      api = RokuAPI.new(config: @config)
      response = Minitest::Mock.new
      response.expect(:success?, true)
      response.expect(:verify!, true)
      api.stub(:get_channel_versions, api_versions) do 
        api.stub(:create_channel_version, response) do
          api.stub(:get_package, "") do
            assert api.submit(options: @options).verify!
          end 
        end 
      end 
      assert_mock response
    end

    def test_submit_response_updated
      api = RokuAPI.new(config: @config)
      response = Minitest::Mock.new
      response.expect(:success?, true)
      response.expect(:verify!, true)
      versions = api_versions
      versions[0]["channelState"] = "Unpublished"
      api.stub(:get_channel_versions, versions) do 
        api.stub(:update_channel_version, response) do
          api.stub(:get_package, "") do
            assert api.submit(options: @options).verify!
          end 
        end 
      end 
      assert_mock response
    end

    def test_publish_response
      api = RokuAPI.new(config: @config)
      response = Minitest::Mock.new
      response.expect(:success?, true)
      response.expect(:verify!, true)
      versions = api_versions
      versions[0]["channelState"] = "Unpublished"
      api.stub(:get_channel_versions, versions) do 
        api.stub(:publish_channel_version, response) do
          assert api.publish(options: @options).verify!
        end 
      end 
      assert_mock response
    end
  end
end
