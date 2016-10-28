require 'sinatra'
require 'line/bot'
require 'rest-client'
require 'pp'
require 'faraday'

def client
    @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }

    @chatwork = Faraday::Connection.new(url: 'https://api.chatwork.com') do |builder|
      builder.use Faraday::Request::UrlEncoded
      builder.use Faraday::Response::Logger
      builder.use Faraday::Adapter::NetHttp
    end
end

def get_user_local_bot_reply(word)
    response = RestClient.get 'https://chatbot-api.userlocal.jp/api/chat', { params: { key: ENV['USR_LOCAL_API_KEY'], message: CGI.escape(word) } }
    response_json = JSON.parse(response)
    response_json['status'] == "success" ? response_json['result'] : '通信エラー'
end

get '/' do
    response = @chatwork.post do |request|
      request.url "/v1/rooms/#{ENV["CHATWORK_ROOMID"]}/messages"
      request.headers = {
        'X-ChatWorkToken' => ENV["CHATWORK_TOKEN"]
      }
      request.params[:body] = "Hello World!" # => ここに入れる文字が投稿される
    end
    "OK"
end


post '/callback' do
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
        error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)
    events.each { |event|
        pp event
        case event
        when Line::Bot::Event::Message
            case event.type
            when Line::Bot::Event::MessageType::Text
                message = {
                    type: 'text',
                    text: event.message['text']
                }
                puts "callback message."
                client.reply_message(event['replyToken'], message)
            when Line::Bot::Event::Beacon
                message = {
                    type: 'text',
                    text: 'おかえり！'
                }
                client.reply_message(event['replyToken'], message)
            when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
                response = client.get_message_content(event.message['id'])
                tf = Tempfile.open("content")
                tf.write(response.body)
            end
        end
    }

    "OK"
end
