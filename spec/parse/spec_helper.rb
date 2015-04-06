require 'spec_helper'

RSpec.shared_examples 'an exception parser' do |parse|
  let :exception do
    FakeException.new message:   'some message',
                      backtrace: ["/Users/someone/a/b/c.rb:123:in `some_method_name'"]
  end

  it 'records the exception, class name, and explanation comes from the message' do
    info = parse.call exception
    expect(info.exception  ).to equal exception
    expect(info.classname  ).to eq 'FakeException'
    expect(info.explanation).to eq 'some message'
  end

  it 'records the backtrace locations' do
    info = parse.call exception
    expect(info.backtrace.map &:linenum).to eq [123]
  end
end