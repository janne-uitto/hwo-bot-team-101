require 'socket'
require 'rubygems'
require 'json'
require 'fileutils'
require 'launchy'


module Pingpong
  class Client
    @@messagecounter = [0,0,0,0,0,0,0,0,0,0,0]
	@@speed = 0
	
	
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
			Launchy.open("#{message['data']}")
          when 'gameStarted'
            puts '... game on!'
          when 'gameIsOn'
            #puts "\nChallenge from server: #{json}\n"
			#puts @@speed
            if (message['data']['ball']['pos']['y']) < (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])
				if(@@speed != -1.0)
					if(countmessages(message['data']['time'])) 
						puts "Up"
						tcp.puts movement_message(-1.0)
						@@speed = -1.0
					end
				end
			elsif (message['data']['ball']['pos']['y'])  > (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])
				if(@@speed != 1.0)
					if(countmessages(message['data']['time'])) 
						puts "Down"
						tcp.puts movement_message(1.0)
						@@speed = 1.0
					end
				end
			else
				if(@@speed != 0.0)
					if(countmessages(message['data']['time'])) 
						puts "Stay"
						tcp.puts movement_message(0)
						@@speed = 0
					end
				end
			end
		else
			puts "Undefined message"
			@@speed = 0.001
			react_to_messages_from_server tcp
        end
      end
    end

    def join_message(player_name)
      %Q!{"msgType":"join","data":"#{player_name}"}!
    end

    def movement_message(delta)
	  %Q!{"msgType":"changeDir","data":#{delta}}!
    end
	
	def countmessages(timestamp)
		@@messagecounter[10] = timestamp
		if @@messagecounter[0] == 0
			for i in 1..10 #t‰ss‰ siirret‰‰n kaikkia taulukon arvoja yhdell‰ vasemmalle
				@@messagecounter[i-1] = @@messagecounter[i]
				puts @@messagecounter[i-1]
			end
			puts "Count messages true < 10"
			return true
		elsif @@messagecounter[10] > @@messagecounter[0] + 1000
			for i in 1..10 #t‰ss‰ siirret‰‰n kaikkia taulukon arvoja yhdell‰ vasemmalle
				@@messagecounter[i-1] = @@messagecounter[i]
				puts @@messagecounter[i-1]
			end
			puts "Count messages true"
			return true
		else
			puts "Count messages FALSE"
			return false
		end
	end	
  end
end

player_name = ARGV[0]
server_host = ARGV[1]
server_port = ARGV[2]
client = Pingpong::Client.new(player_name, server_host, server_port)
