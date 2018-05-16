require 'spec_helper'

describe 'foo' do
  it 'bar' do
    puts '[DEBUG] bar start'
    expect(true).to be_truthy
  end
end
