# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class PackagerTest < Minitest::Test
  def test_packager_package_failed
    connection = Minitest::Mock.new
    faraday = Minitest::Mock.new
    response = Minitest::Mock.new

    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    payload = {
      mysubmit: "Package",
      app_name: "app_name",
      passwd: "password",
      pkg_time: 0
    }
    package_config ={
      app_name_version: "app_name",
      out_file: "out_file",
      password: "password"
    }
    path = "/plugin_package"

    faraday.expect(:headers, {})
    faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
    faraday.expect(:request, nil, [:multipart])
    faraday.expect(:request, nil, [:url_encoded])
    faraday.expect(:adapter, nil, [Faraday.default_adapter])
    connection.expect(:post, response) do |arg1, arg2|
      assert_equal path, arg1
      assert_equal payload[:mysubmit], arg2[:mysubmit]
      assert_equal payload[:app_name], arg2[:app_name]
      assert_equal payload[:passwd], arg2[:passwd]
      assert_equal payload[:pkg_time], arg2[:pkg_time]
    end
    response.expect(:body, "Failed: Error.")

    packager = RokuBuilder::Packager.new(**device_config)
    result = nil
    Faraday.stub(:new, connection, faraday) do
      Time.stub(:now, Time.at(0)) do
        result = packager.package(**package_config)
      end
    end

    assert_equal "Failed: Error.", result

    connection.verify
    faraday.verify
    response.verify
  end

  def test_packager_package
    connection = Minitest::Mock.new
    faraday = Minitest::Mock.new
    response = Minitest::Mock.new
    io = Minitest::Mock.new

    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    payload = {
      mysubmit: "Package",
      app_name: "app_name",
      passwd: "password",
      pkg_time: 0
    }
    package_config ={
      app_name_version: "app_name",
      out_file: "out_file",
      password: "password"
    }
    path = "/plugin_package"

    faraday.expect(:headers, {})
    faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
    faraday.expect(:request, nil, [:multipart])
    faraday.expect(:request, nil, [:url_encoded])
    faraday.expect(:adapter, nil, [Faraday.default_adapter])

    faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
    faraday.expect(:adapter, nil, [Faraday.default_adapter])

    connection.expect(:post, response) do |arg1, arg2|
      assert_equal path, arg1
      assert_equal payload[:mysubmit], arg2[:mysubmit]
      assert_equal payload[:app_name], arg2[:app_name]
      assert_equal payload[:passwd], arg2[:passwd]
      assert_equal payload[:pkg_time], arg2[:pkg_time]
    end
    connection.expect(:get, response, ["/pkgs/pkg_url"])

    response.expect(:body, "<a href=\"pkgs\">pkg_url</a>")
    response.expect(:body, "<a href=\"pkgs\">pkg_url</a>")

    response.expect(:status, 200)
    response.expect(:body, "package_body")

    io.expect(:write, nil, ["package_body"])

    packager = RokuBuilder::Packager.new(**device_config)
    result = nil
    Faraday.stub(:new, connection, faraday) do
      Time.stub(:now, Time.at(0)) do
        File.stub(:open, nil, io) do
          result = packager.package(**package_config)
        end
      end
    end

    assert_equal true, result

    connection.verify
    faraday.verify
    response.verify
    io.verify
  end
end
