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
  end
end
