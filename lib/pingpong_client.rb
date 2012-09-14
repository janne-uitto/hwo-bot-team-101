require 'socket'
require 'rubygems'
require 'json'
require 'launchy'


module Pingpong
    class Client
        @@messagecounter = [0,0,0,0,0,0,0,0,0,0,0]
        @@targetcounter = [0,0,0]
        @@speed = 0
        @@prevBallX = 0
        @@target = 0
        @@wins = 0
        @@games = 0
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
                        moveThresholdSlow = 5
                        moveThreshold = message['data']['conf']['paddleHeight']

					    if ((message['data']['ball']['pos']['x'] > moveThreshold))# || (message['data']['ball']['pos']['x'] < message['data']['conf']['maxWidth'] - moveThreshold))    #ei lasketa uutta targettia jos liian lähellä
						  if (directionIsLeft(message['data']['ball']['pos']['x']))
							@newtarget = calculate_path(tcp, true)
						  else
							#@newtarget = calculate_path(tcp, false) # kommentoi tämä jos et halua että lasketaan targettia
# tässä voidaan valita mitä tehdään kun mennään pois                                
							# poista kommentit alta jos haluat että ei lasketa targettia
							@newtarget = message['data']['conf']['maxHeight'] / 2
							for i in 0..2 # nollataan taulukko jossa on kolme viimesintä targettia
							    @@targetcounter[i] = 0 
							end
						  end
						  @@target = @newtarget
						  #puts "Palautettu target #{@@target}"
						  if (@@target < message['data']['conf']['paddleHeight'] / 2) # jos ollaan liian lähellä reunaa
							@@target = moveThresholdSlow # korjataan targettia ettei maila bouncaa reunasta
						  elsif(@@target > (message['data']['conf']['maxHeight'] - message['data']['conf']['paddleHeight'] / 2))
							@@target = message['data']['conf']['maxHeight'] - moveThresholdSlow
						  end
						  
						else # jos ollaan oman mailan lähellä
						  for i in 0..2 # nollataan taulukko jossa on kolme viimesintä targettia
						    @@targetcounter[i] = 0 
						  end
						end
                         
                        #puts "Mailan keskikohta: #{message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']}"
                        if ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) > (@@target + moveThreshold))
                            moveUp(message, tcp)
                        elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) < (@@target - moveThreshold))
                            moveDown(message, tcp)
                        elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) > (@@target + moveThresholdSlow))
                            moveUpSlow(message, tcp)
                        elsif ((message['data']['conf']['paddleHeight'] / 2 + message['data']['left']['y']) < (@@target - moveThresholdSlow))
                            moveDownSlow(message, tcp)
                        else
                            moveStay(message, tcp)
						end
                    
                    when 'gameIsOver'
                        gameover(message)
                    else
                        puts "Undefined message"
                        @@speed = 0.01
                end
            end
        end
		
		def gameover(message)
          @@games = @@games + 1
		  if message['data'] == ARGV[0] then @@wins = @@wins + 1 end
		  puts "Voittaja #{message['data']}!"
		  puts "Voittoja/peleja: #{@@wins}/#{@@games}"
		  @@speed = 0.01
        end
        
        def join_message(player_name)
            %Q!{"msgType":"join","data":"#{player_name}"}!
        end
        
        def movement_message(delta)
            %Q!{"msgType":"changeDir","data":#{delta}}!
        end
        
        def countmessages(timestamp)
            @@messagecounter[10] = timestamp        # tallennetaan uusin aika taulukkoon jotta voidaan tarkistaa että ollaanko liikaa käskytetty
            #puts "DIFF: #{@@messagecounter[10]-@@messagecounter[0]}"
            if @@messagecounter[0] == 0 || @@messagecounter[10] > @@messagecounter[0] + 1000    # jos ei olla vielä käskytetty 10 kertaa ylipäätään
              for i in 1..10                                                                                                                                         # tai 10. käskytus on yli sekunnin päässä
                @@messagecounter[i-1] = @@messagecounter[i] #tässä siirretään kaikkia taulukon arvoja yhdellä vasemmalle
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
        
        def calculate_path(tcp, kohti)
            @points = []
            @height = 480
            @paddleWidth = 10
            3.times do |num|
                json = tcp.gets
                message = JSON.parse(json)
                @@coord = Coordinates.new(0,0)
                if (message['msgType'] == 'gameIsOn')
                    @height = message['data']['conf']['maxHeight']
                    @width = message['data']['conf']['maxWidth']
                    @paddleWidth = message['data']['conf']['paddleWidth']
                    #@@coord = Coordinates.new(0,0)
                    @@coord.x = message['data']['ball']['pos']['x'] if message['msgType'] == 'gameIsOn'
                    @@coord.y = message['data']['ball']['pos']['y'] if message['msgType'] == 'gameIsOn'
                    @points[num] = @@coord
                elsif (message['msgType'] == 'gameIsOver')
				  gameover(message)
				  break calculate_path(tcp, kohti)
				else
				  break calculate_path(tcp, kohti)
				  #react_to_messages_from_server(tcp)
				end
            end
            delta_x = @points[0].x - @points[1].x
            delta_y = @points[0].y - @points[1].y
            #delta_x2 = @points[1].x - @points[2].x
            #delta_y2 = @points[1].y - @points[2].y
              
            #puts "deltax: #{delta_x}, deltay: #{delta_y}"
            #puts "deltax2: #{delta_x2}, deltay2: #{delta_y2}"
              
            if (kohti)
                extrapolate = -(((delta_y*(@points[0].x - 10))/delta_x) - @points[0].y)
            else
                extrapolate = -2*(((delta_y*(@width-@points[0].x))/delta_x) - @points[0].y)
            end
          
            #puts extrapolate
            while (extrapolate < -@height) # jos ollaan ylhäältä enemmän kuin yhden ruudun verran yli
                extrapolate = extrapolate + @height # niin lisätään ruutuja kunnes ollaan yhden ruudun päässä
            end
            while (extrapolate > 2 * @height) # jos ollaan alhaalta enemmän kuin yhden ruudun verran ali
                extrapolate = extrapolate - @height # vähennetään kunnes ruudun päässä
            end
            if extrapolate < 0 # jos ollaan ylhäältä ohi (tässä vaiheessa vain yhden ruudun)
                targettemp = extrapolate + @height	# lisätään ruutu ( nyt ollaan pelialueela )
				targettemp = @height - targettemp # ja peilataan se
                targettemp = targettemp + 12	# lisätään seinästä kimpoamista
            elsif extrapolate > @height	# jos ollaan alhaalta ohi
                targettemp = extrapolate - @height # lisätään ruutu
                targettemp = @height - targettemp	# peilataan
                targettemp = targettemp - 12 		# seinästä kimpoaminen
            else 
                targettemp = extrapolate 	#ollaan jo peli alueella
            end
			
#			while (extrapolate < @height)
#                extrapolate = extrapolate + 2 * @height
#            end
#            while (extrapolate > 2 * @height)
#                extrapolate = extrapolate - 2 * @height
#            end
#            if extrapolate < 0
#                targettemp = -extrapolate
#                targettemp = targettemp * 1.05
#            elsif extrapolate > @height
#                targettemp = extrapolate - @height 
#                targettemp = @height - targettemp
#                targettemp = targettemp * 0.96
#            else 
#                targettemp = extrapolate 
#            end
          
            @@target = targettemp
          
            puts "Laskettu target #{@@target}"
          
            @@targetcounter[0] = @@targetcounter[1]
            @@targetcounter[1] = @@targetcounter[2] # siirretään taulukon arvoja yhdellä
            @@targetcounter[2] = @@target			# tallennetaan viimeksi lastettu target taulukkoon
													# on pallo menossa kumpaan suuntaan tahansa
		    temptargetcounter = [0,0,0]
            for i in 0..2	# kopioidaan taulukko jotta sen voi sortata
			  temptargetcounter[i] = @@targetcounter[i]	
			end
			
            #if (kohti)
                if(temptargetcounter[0] > temptargetcounter[1]) ## bubble sort käsin
                    temptargetcounter[0], temptargetcounter[1] = temptargetcounter[1], temptargetcounter[0]  
                end
                if(temptargetcounter[1] > temptargetcounter[2])
                    temptargetcounter[1], temptargetcounter[2] = temptargetcounter[2], temptargetcounter[1]  
                end
                if(temptargetcounter[0] > temptargetcounter[1])
                    temptargetcounter[0], temptargetcounter[1] = temptargetcounter[1], temptargetcounter[0]  
                end
              
                if (temptargetcounter[1] == 0) # jos taulukossa ei ole kuin yksi arvo
                    return temptargetcounter[2]  # niin palautetaan se ainoa arvo ( taulukko on sortattu )
                else
                    return temptargetcounter[1] # muuten palautetaan keskimmäinen
                end
            #else
            #    return targettemp
            #end
        end
        
        def moveUp(message, tcp)
            if(@@speed != -1.0) ## jos mennään jo ylös täyttä vauhtia niin ei muuteta mitään
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

