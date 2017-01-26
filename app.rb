require 'pry'
require 'dotenv'
require 'RMagick'
require 'mechanize'
require 'open-uri'
require 'rest-client'
require 'slack-ruby-client'

Dotenv.load!

class Emoji
  def initialize
  end

  def download_file(name, url)
    res = RestClient.get(url, { "Authorization" => "Bearer #{ENV['SLACK_TOKEN']}" })

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

  def login(team, email, password)
  end

  def upload(team, email, password, file_name)
    base_url = "https://#{team}.slack.com"
    emoji_name = File.basename(file_name, '.*')
    agent = Mechanize.new

    agent.get(base_url) do |page|
      res = page.form_with(action: '/') do |form|
        form.field_with(name: 'email').value = email
        form.field_with(name: 'password').value = password
      end.submit

      if res.code != '200'
        puts "[#{res.code}] Login failed."
        return -1
      end

      agent.get("#{base_url}/customize/emoji") do |page|
        if page.body.include?(":#{emoji_name}:")
          puts ":#{emoji_name}: is already exists."
        else
          puts "Uploading :#{emoji_name}:..."
          res = page.form_with(action: '/customize/emoji') do |form|
            form.field_with(name: 'name').value = emoji_name
            form.radiobuttons_with(name: 'mode')[0].check
            form.file_upload_with(name: 'img').file_name = file_name
          end.submit
          puts "Updated :#{emoji_name}:!"
        end
      end
    end
  end
end

Slack.configure do |config|
  config.token = ENV['SLACK_TOKEN']
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
  if data.file
    file = data.file
    begin
      emoji = Emoji.new
      emoji.download_file(file.title, file.url_private)
      emoji.resize_file(file.title)
      emoji.upload(ENV['SLACK_TEAM'], ENV['SLACK_EMAIL'], ENV['SLACK_PASS'], file.title)
      client.message(channel: data.channel, text: "Added an emoji! :#{File.basename(file.title, '.*')}:")
    rescue => e
      puts e
      client.message(channel: data.channel, text: "Couldn't add an emoji.")
    end
  end
end

client.start!
