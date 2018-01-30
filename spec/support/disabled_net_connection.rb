#if ENV['DISABLED_NET_CONNECTION']
require 'webmock'
include WebMock::API

WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)

#require 'webmock/rspec'
#end
