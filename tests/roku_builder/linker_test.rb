# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class LinkerTest < Minitest::Test
  def test_linker_link
    connection = Minitest::Mock.new
    faraday = Minitest::Mock.new
    response = Minitest::Mock.new

    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    path = "/launch/dev?a=A&b=B%3AC&d=a%5Cb"
    options = 'a:A, b:B:C, d:a\b'

    connection.expect(:post, response, [path])
    faraday.expect(:headers, {})
    faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
    faraday.expect(:request, nil, [:multipart])
    faraday.expect(:request, nil, [:url_encoded])
    faraday.expect(:adapter, nil, [Faraday.default_adapter])
    response.expect(:success?, true)

    linker = RokuBuilder::Linker.new(**device_config)
    success = nil
    Faraday.stub(:new, connection, faraday) do
      success = linker.launch(options: options)
    end

    assert success

    connection.verify
    faraday.verify
    response.verify
  end
  def test_linker_link_nothing
    logger = Minitest::Mock.new
    connection = Minitest::Mock.new
    faraday = Minitest::Mock.new
    response = Minitest::Mock.new

    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    path = "/launch/dev"
    options = ''
    logger.expect(:warn, nil, ["No options sent to launched app"])
    connection.expect(:post, response, [path])
    faraday.expect(:headers, {})
    faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
    faraday.expect(:request, nil, [:multipart])
    faraday.expect(:request, nil, [:url_encoded])
    faraday.expect(:adapter, nil, [Faraday.default_adapter])
    response.expect(:success?, true)
    linker = RokuBuilder::Linker.new(**device_config)
    success = nil
    Faraday.stub(:new, connection, faraday) do
      success = linker.launch(options: options)
    end

    assert success
    logger.verify
    connection.verify
    faraday.verify
    response.verify
  end

  def test_linker_list
    connection = Minitest::Mock.new
    faraday = Minitest::Mock.new
    response = Minitest::Mock.new

    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    path = "/query/apps"
    body = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<apps>\n\t
<app id=\"31012\" type=\"menu\" version=\"1.6.3\">Movie Store and TV Store</app>\n\t
<app id=\"31863\" type=\"menu\" version=\"1.2.6\">Roku Home News</app>\n\t
<app id=\"65066\" type=\"appl\" version=\"1.3.0\">Nick</app>\n\t
<app id=\"68161\" type=\"appl\" version=\"1.3.0\">Nick</app>\n\t
</apps>\n"
    connection.expect(:get, response, [path])
    faraday.expect(:headers, {})
    faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
    faraday.expect(:request, nil, [:multipart])
    faraday.expect(:request, nil, [:url_encoded])
    faraday.expect(:adapter, nil, [Faraday.default_adapter])
    response.expect(:success?, true)
    response.expect(:body, body)
    linker = RokuBuilder::Linker.new(**device_config)

    print_count = 0
    did_print = Proc.new { |msg| print_count+=1 }

    Faraday.stub(:new, connection, faraday) do
      linker.stub(:printf, did_print) do
        linker.list
      end
    end

    assert_equal 6, print_count
  end
end
