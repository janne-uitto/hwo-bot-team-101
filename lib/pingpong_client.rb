require 'socket'
require 'rubygems'
require 'json'
require 'launchy'


module Pingpong
  class Client
    @@messagecounter = [0,0,0,0,0,0,0,0,0,0,0]
	@@speed = 0
	@@prevBallX = 0
	@@target = 0
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
			moveThresholdSlow = 5
			moveThreshold = message['data']['conf']['paddleHeight']
			if(directionIsLeft(message['data']['ball']['pos']['x']))
			  ## direction to you
		      if message['data']['ball']['pos']['x'] > moveThreshold ## t‰ss‰ oli 100
			    @curtarget = calculate_path(tcp)
				if(@curtarget < message['data']['conf']['paddleHeight'] / 2)
				  @curtarget = message['data']['conf']['paddleHeight'] / 2
				elsif(@curtarget > (message['data']['conf']['maxHeight'] - message['data']['conf']['paddleHeight'] / 2))
				  @curtarget = message['data']['conf']['maxHeight'] - message['data']['conf']['paddleHeight'] / 2
				end
			  end
			else
			## direction away from me
				@curtarget = message['data']['conf']['maxHeight'] / 2	
			end
			@@target = @curtarget
			#puts "Mailan keskikohta: #{message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']}"
			if ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) > (@curtarget + moveThreshold))
				moveUp(message, tcp)
			elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) < (@curtarget - moveThreshold))
				moveDown(message, tcp)
			elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) > (@curtarget + moveThresholdSlow))
				moveUpSlow(message, tcp)
			elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) < (@curtarget - moveThresholdSlow))
				moveDownSlow(message, tcp)
			else
				moveStay(message, tcp)
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
	  @height = 480
	  @paddleWidth = 10
	  3.times do |num|
		json = tcp.gets
		message = JSON.parse(json)
		if (message['msgType'] == 'gameIsOn')
		  @height = message['data']['conf']['maxHeight']
		  @paddleWidth = message['data']['conf']['paddleWidth']
		  @@coord = Coordinates.new(0,0)
		  @@coord.x = message['data']['ball']['pos']['x'] if message['msgType'] == 'gameIsOn'
	      @@coord.y = message['data']['ball']['pos']['y'] if message['msgType'] == 'gameIsOn'
		  @points[num] = @@coord
		end
	  end
	  delta_x = @points[0].x - @points[1].x
	  delta_y = @points[0].y - @points[1].y
	  extrapolate = -(((delta_y*(@points[0].x - 10))/delta_x) - @points[0].y)
	  
	  
	  #puts extrapolate
	  if extrapolate < 0
	    targettemp = -extrapolate
		targettemp = targettemp * 1.05
	  elsif extrapolate > @height
	    targettemp = extrapolate - @height 
		targettemp = @height - targettemp
		targettemp = targettemp * 0.96
	  else 
	    targettemp = extrapolate 
	  end
	  #unless(targettemp < @@target+50 || targettemp > @@target+50)
	    @@target = targettemp
	  #end
	  
	  puts "Target #{@@target}"
	  return @@target	
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
	def moveUpSlow(message, tcp)
		if(@@speed != -0.2)
			if(countmessages(message['data']['time']))
				puts "UpSlow"
				tcp.puts movement_message(-0.2)
				@@speed = -0.2
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
	def moveDownSlow(message, tcp)
		if(@@speed != 0.2)
			if(countmessages(message['data']['time'])) 
				puts "DownSlow"
				tcp.puts movement_message(0.2)
				@@speed = 0.2
			end
		end
	end
	
	def moveStay(message, tcp)
		if(@@speed != 0.0)
			if(countmessages(message['data']['time'])) 
				puts "Stay: #{message['data']['left']['y'] +  message['data']['conf']['paddleHeight'] / 2}"
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
