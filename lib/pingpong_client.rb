require 'socket'
require 'rubygems'
require 'json'
require 'launchy'


module Pingpong
  class Client
    @@messagecounter = [0,0,0,0,0,0,0,0,0,0,0]
	@@speed = 0
	@@prevBallX = 0;
	Coordinates = Struct.new(:x,:y)
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
      @target = 240
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
			moveThreshold = 10
			if(directionIsLeft(message['data']['ball']['pos']['x']))
			  ## direction to you
		      if message['data']['ball']['pos']['x'] > 100
			    @target = calculate_path(tcp)
			  end
			  #if (message['data']['ball']['pos']['y']) < (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])
				#moveUp(message, tcp)
			  #elsif (message['data']['ball']['pos']['y']) > (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])
				#moveDown(message, tcp)
			  #else
				#moveStay(message, tcp)
			  if @target < (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])
				moveUp(message, tcp)
			  elsif @target > (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])
				moveDown(message, tcp)
			  elsif (@target == (message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y'])) || (@target == (message['data']['conf']['paddleHeight'] / 2 - message['data']['left']['y']))
				moveStay(message, tcp)
			  end
			else
				## direction away from me
				if ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) > (message['data']['conf']['maxHeight'] / 2 + moveThreshold))
					moveUp(message, tcp)
				elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) < (message['data']['conf']['maxHeight'] / 2 - moveThreshold))
					moveDown(message, tcp)
				else
					moveStay(message, tcp)
				end
			end
		else
			puts "Undefined message"
			@@speed = 0.01
			#react_to_messages_from_server tcp
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
		@@messagecounter[10] = timestamp	# tallennetaan uusin aika taulukkoon jotta voidaan tarkistaa ett‰ ollaanko liikaa k‰skytetty
		if @@messagecounter[0] == 0 || @@messagecounter[10] > @@messagecounter[0] + 1000	# jos ei olla viel‰ k‰skytetty 10 kertaa ylip‰‰t‰‰n
			for i in 1..10 																	# tai 10. k‰skytus on yli sekunnin p‰‰ss‰
				@@messagecounter[i-1] = @@messagecounter[i] #t‰ss‰ siirret‰‰n kaikkia taulukon arvoja yhdell‰ vasemmalle
				#puts @@messagecounter[i-1]
			end
			#puts "Count messages TRUE"
			return true
		else
			puts "Count messages FALSE"
			return false
		end
	end	
	
	def directionIsLeft(currentX)
		if( currentX < @@prevBallX)
			@@prevBallX = currentX
			return true
		else
			@@prevBallX = currentX
			return false
		end
	end
	
	def calculate_path(tcp)
	  @points = []
	  3.times do |num|
		json = tcp.gets
		message = JSON.parse(json)
		if (message['msgType'] = 'gameIsOn')
		  @@coord = Coordinates.new(0,0)
		  @@coord.x = message['data']['ball']['pos']['x'] if message['msgType'] = 'gameIsOn'
	      @@coord.y = message['data']['ball']['pos']['y'] if message['msgType'] = 'gameIsOn'
		  @points[num] = @@coord
		end
	  end
	  delta_x = @points[0].x - @points[1].x
	  delta_y = @points[0].y - @points[1].y
	  extrapolate = -(((delta_y*@points[0].x)/delta_x)-@points[0].y)
	  
	  #puts extrapolate
	  if extrapolate < 0
	    target = -extrapolate  
	  elsif extrapolate > 480
	    target = extrapolate - 480 
	  else 
	    target = extrapolate 
	  end
	  puts target
	  return target	
	end
	def moveUp(message, tcp)
		if(@@speed != -1.0) ## jos menn‰‰n jo ylˆs t‰ytt‰ vauhtia niin ei muuteta mit‰‰n
			if(countmessages(message['data']['time']))  # tarkistetaan 10 komentoa/sec
				puts "Up"
				tcp.puts movement_message(-1.0)
				@@speed = -1.0
			end
		end
	end
	
	def moveDown(message, tcp)
		if(@@speed != 1.0)
			if(countmessages(message['data']['time'])) 
				puts "Down"
				tcp.puts movement_message(1.0)
				@@speed = 1.0
			end
		end
	end
	
	def moveStay(message, tcp)
		if(@@speed != 0.0)
			if(countmessages(message['data']['time'])) 
				puts "Stay"
				tcp.puts movement_message(0)
				@@speed = 0
			end
		end
	end
	
	
  end
end


player_name = ARGV[0]
server_host = ARGV[1]
server_port = ARGV[2]
client = Pingpong::Client.new(player_name, server_host, server_port)
