#
require 'rubygems'
require 'bundler'

Bundler.require(:default, :development)

Dotenv.load

[
  './helpers',
  './asset_rules',
  './page_rules',
  './stylesheet_rules',
  './capture'
].each { |lib| require_relative lib }

desc 'Capture site [source="https://web.unimelb.edu.au"]'
task 'capture' do
  # Unpack args
  opts = {}
  ARGV.each do |arg|
    arg = arg.split('=')
    opts[arg.first.to_sym] = arg.last
  end

  abort 'Missing source url' unless opts.include? :source

  Capture.new(opts: opts)
end

task default: :capture
