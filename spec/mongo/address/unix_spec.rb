require 'spec_helper'
# require 'mongo'

puts "[DEBUG] after spec_helper"
puts `ss -ltnp`

# describe Mongo::Address::Unix do
describe Mongo do
# describe Foo do

  puts "[DEBUG] unix_spec.rb Mongo::Address::Unix"
  puts `ss -ltnp`

  # let(:resolver) do
  #   puts "[DEBUG] resolver"
  #   puts `ss -ltnp`
  #   described_class.new(*described_class.parse(address))
  # end

  describe '#socket' do

    puts "[DEBUG] unix_spec.rb Mongo::Address::Unix#socket"
    puts `ss -ltnp`

    # let(:address) do
    #   puts "[DEBUG] address"
    #   puts `ss -ltnp`
    #   '/tmp/mongodb-27017.sock'
    # end

    # let(:socket) do
    #   puts "[DEBUG] socket"
    #   puts `ss -ltnp`
    #   resolver.socket(5)
    # end

    it 'returns a unix socket' do
      puts "[DEBUG] returns-a-unix-socket start"
      puts `ss -ltnp`
      # expect(socket).to be_a(Mongo::Socket::Unix)
      expect(true).to be_truthy
    end
  end
end
