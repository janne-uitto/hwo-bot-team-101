require 'socket'
require 'rubygems'
require 'json'
require 'fileutils'
require 'launchy'

module Pingpong
  class Client
    def initialize(player_name, server_host, server_port)
      tcp = TCPSocket.open(server_host, server_port)
      play(player_name, tcp)
    end
	
	Coordinates = Struct.new(:x,:y)
	#@@coord = Coordinates.new(5,6)
    
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
            #puts "Game visualization url #{message['data']}"
			Launchy.open("#{message['data']}")
		  when 'gameStarted'
            puts '... game on!'
          when 'gameIsOn'
            #puts "Challenge from server: #{json}"
            points = calculate_path(tcp)
			tcp.puts movement_message(-1.0)
			points.each do |piste|
			  puts piste
			end
        end
      end
    end

    def join_message(player_name)
      %Q!{"msgType":"join","data":"#{player_name}"}!
    end

    def movement_message(delta)
      %Q!{"msgType":"changeDir","data":#{delta}}!
    end
	
	def calculate_path(tcp)
	  @points = []
	  10.times do |num|
	    sleep 0.1
		json = tcp.gets
		message = JSON.parse(json)
		@@coord = Coordinates.new(0,0)
	    @@coord.x = message['data']['ball']['pos']['x']
	    @@coord.y = message['data']['ball']['pos']['y']
		@points[num] = @@coord
	    end
	  return @points	
	end
	
  end
end

player_name = ARGV[0]
server_host = ARGV[1]
server_port = ARGV[2]
client = Pingpong::Client.new(player_name, server_host, server_port)
