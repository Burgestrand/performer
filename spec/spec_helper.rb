require "puddle"
require "timeout"

module ConcurrencyUtilities
  def wait_until_sleep(thread)
    Thread.pass until thread.status == "sleep"
  end
end

RSpec.configure do |config|
  config.include(ConcurrencyUtilities)

  config.expect_with :rspec do |c|
    c.syntax = :should
  end

  config.mock_with :rspec do |c|
    c.syntax = :should
  end

  config.around(:each) do |example|
    Timeout.timeout(5, &example)
  end
end
