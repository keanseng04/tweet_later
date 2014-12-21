# Set up gems listed in the Gemfile.
# See: http://gembundler.com/bundler_setup.html
#      http://stackoverflow.com/questions/7243486/why-do-you-need-require-bundler-setup
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])

# Require gems we care about
require 'rubygems'

require 'uri'
require 'pathname'

require 'pg'
require 'active_record'
require 'logger'

require 'sinatra'
require "sinatra/reloader" if development?

require 'erb'

require 'omniauth-twitter'
require 'twitter'

configure do
  enable :sessions
end

require 'sidekiq'
require 'sidekiq/api'
require 'redis'


# Some helper constants for path-centric logic
APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))

APP_NAME = APP_ROOT.basename.to_s

# Set up the controllers and helpers
Dir[APP_ROOT.join('app', 'controllers', '*.rb')].each { |file| require file }
Dir[APP_ROOT.join('app', 'helpers', '*.rb')].each { |file| require file }

# Set up the database and models
require APP_ROOT.join('config', 'database')

if Sinatra::Application.development?
  API_KEYS = YAML::load(File.open('config/api_keys.yaml'))
  TWITTER_KEYS = API_KEYS['development']['TWITTER_KEY']
  TWITTER_SECRETS = API_KEYS['development']['TWITTER_SECRET']
else
  TWITTER_KEYS = ENV['TWITTER_KEY']
  TWITTER_SECRETS = ENV['TWITTER_SECRET']
end

use OmniAuth::Builder do
  provider :twitter, TWITTER_KEYS, TWITTER_SECRETS
end