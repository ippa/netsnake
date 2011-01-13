#
#
#
class Server < Chingu::GameStates::NetworkServer
  trait :timer
  
  def initialize
    super
    
    @ip = options[:ip] || "0.0.0.0"
    @port = options[:port] || 7778
    start(@ip, @port)
        
    @width = 600
    @height = 400
    @level_array = Array.new(@width) { Array.new(@height) }
    @max_players = 4
    
    # x, y, velocity_x, velocity_y
    @start_positions = [ 
                       [10, 10, 1, 0],
                       [@width-10,@height-10,-1,0],
                       [@width-10,10,-1,0],
                       [10,@height-10,1,0]
                       ]
    @colors = [:red, :cyan, :yellow, :green]
    
    every(5000) { puts "FPS: #{$window.fps}" }
  end
  
  #
  # Called for each new client conecting to out server
  #
  def on_connect(socket)
    if Player.size >= @max_players
      socket.close
    else      
      puts "* New player: #{socket.inspect}"
      player = Player.create
      player.socket = socket
      player.color = (@colors - Player.all.collect{|player| player.color}).first
      
      # If 0 or 1 players, restart game and go
      # If 2+ ppl are playing, new player has to wait
      (Player.size > 2) ? (player.alive = false) : restart_players
    end
  end
  
  def on_disconnect(socket)
    if (player = Player.find_by_socket(socket)) # sometimes on_disconnect gets called twice
      puts "* Player #{player} disconnected"
      player.destroy
      puts "#{Player.size} players left"
    end
  end

  def update    
    super     # Let NetworkServer#update do it's thing, poll incoming connections and data
    
    # World logic, collision detection etc.
    Player.each do |player|
      # Wrap around when reaching window border
      player.x = player.previous_x = 0          if player.x > @width-1
      player.x = player.previous_x = @width-1   if player.x < 0
      player.y = player.previous_y = 0          if player.y > @height-1
      player.y = player.previous_y = @height-1  if player.y < 0
      
      # collide with other snakes
      if player.alive == true && collision_at?(player.x, player.y)
        player.stop
        player.alive = false
        puts "* player #{player.uuid} died"
        
        broadcast_msg(:cmd => :kill, :uuid => player.uuid, :x => player.x, :y => player.y)

        if Player.alive.size == 1
          winner = Player.alive.first
          puts "* Winner: #{winner}"
          broadcast_msg(:cmd => :winner, :uuid => winner.uuid)
          restart
        end
      end
    end
    
    # All players dead, restart level
    if Player.size > 0 && Player.alive.size == 0
      restart
    else
      Player.alive.each { |player| @level_array[player.x][player.y] = true }
      update_clients
    end       
  end
  
  def restart
    puts "* Restarting game ..."
    sleep 0.5
    @level_array = Array.new(@width) { Array.new(@height) }
    restart_players
    sleep 0.5
  end
  
  def restart_players
    Player.each_with_index do |player, index|
      player.alive = true    
      player.start_position = index
      player.x = @start_positions[index][0]
      player.y = @start_positions[index][1]
      player.velocity_x = @start_positions[index][2]
      player.velocity_y = @start_positions[index][3]
      player.previous_x = player.x
      player.previous_y = player.y
      send_msg(player.socket, player.position_data)
      send_msg(player.socket, player.restart_data)
      puts "Started player #{player.uuid} @ postion ##{index}"
    end
  end
  
  def collision_at?(x,y)
    @level_array[x][y]
  end
      
  #
  # Send data for each client to all clients
  #
  def update_clients
    Player.each { |player| broadcast_msg(player.position_data) }
  end
      
  def on_msg(socket, data)
    return unless data && data[:uuid]
    player = Player.find_by_socket(socket)
    puts "-> #{data[:cmd].to_s} from #{data[:uuid]}"
    
    case data[:cmd]
      when :start
        player.uuid = data[:uuid]
      when :pong
        player.latency = (Goso::milliseconds - data[:milliseconds])
        puts "-> PONG from #{player}, latency #{@latency}"
      when :ping
        puts "-> PING from #{player}"
        # Send back timestamp recieved so client on other side can calcuate ping
        send_msg(socket, {:uuid => player.uuid, :cmd => :pong, :milliseconds => data[:milliseconds]} )
      when :position 
        player.x = data[:x]
        player.y = data[:y]
      when :direction
        player.stop
        return  if  player.alive == false
        
        case data[:direction]
          when :right then player.velocity_x = 1
          when :left  then player.velocity_x = -1
          when :up    then player.velocity_y = -1
          when :down  then player.velocity_y = 1
        end
    end
  end
end

# If fils is executed, not required.
if __FILE__ == $0
  Server.new.show
end
