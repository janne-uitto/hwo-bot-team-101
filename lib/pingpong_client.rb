require 'socket'
require 'rubygems'
require 'json'
require 'fileutils'

module Pingpong
  class Client
    def initialize(player_name, server_host, server_port)
      tcp = TCPSocket.open(server_host, server_port)
      play(player_name, tcp)
    end

    private

    def play(player_name, tcp)
      tcp.puts join_message(player_name)
      react_to_messages_from_server tcp
    end

    def react_to_messages_from_server(tcp)
      while json = tcp.gets
        message = JSON.parse(json)
        case message['msgType']
          when 'joined'
            puts "Game visualization url #{message['data']}"
          when 'gameStarted'
            puts '... game on!'
          when 'gameIsOn'
            puts "Challenge from server: #{json}"
            tcp.puts movement_message(-1.0)
        end
      end
    end

    def join_message(player_name)
      %Q!{"msgType":"join","data":"#{player_name}"}!
    end

    def movement_message(delta)
      %Q!{"msgType":"changeDir","data":#{delta}}!
    end
  end
end

player_name = ARGV[0]
server_host = ARGV[1]
server_port = ARGV[2]
client = Pingpong::Client.new(player_name, server_host, server_port)
