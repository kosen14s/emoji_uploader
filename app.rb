require 'slack-ruby-client'
require 'pry'
require 'dotenv'
require 'RMagick'
require 'open-uri'
require 'rest-client'

Dotenv.load!

def download_file(name, url)
  res = RestClient.get(url, { "Authorization" => "Bearer #{ENV['TOKEN']}" })

  if res.code == 200
    File.open(name, "wb") do |f|
      f.puts(res.body)
    end
  else
    raise 'Download failed'
  end
end

def resize_file(name)
  original = Magick::ImageList.new
  url = open(name)
  original.from_blob(url.read)

  image = original.resize_to_fit(128, 128)
  image.write(name)
end

Slack.configure do |config|
  config.token = ENV['TOKEN']
end

client = Slack::RealTime::Client.new

client.on :hello do
  puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
end

client.on :close do |_data|
  puts "Client is about to disconnect"
end

client.on :closed do |_data|
  puts "Client has disconnected successfully!"
end

client.on :message do |data|
  # case data.text
  # when 'bot hi' then
    # client.message channel: data.channel, text: "Hi <@#{data.user}>!"
  # when /^bot/ then
    # client.message channel: data.channel, text: "Sorry <@#{data.user}>, what?"
  # end
  if data.file
    file = data.file
    download_file(file.title, file.url_private)
    resize_file(file.title)
  end
end

client.start!
