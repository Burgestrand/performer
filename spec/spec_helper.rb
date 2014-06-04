require "performer"
require "timeout"

module ConcurrencyUtilities
  def wait_until(thread, status)
    Thread.pass until thread.status == status
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
    Timeout.timeout(1, &example)
  end
end
