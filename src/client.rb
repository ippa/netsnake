class Client < Chingu::GameState
    
  def initialize(options = {})
    @ip = options[:ip] || "192.168.0.1"
    #@ip = options[:ip] || "127.0.0.1"
    @port = 7778
    
    unless @ip
      puts "No serverIP given, please snart netsnake like this:"
      puts "ruby netsnake.rb <ip of server>"
      exit
    end
    
    self.input = [:esc, :left, :right, :up, :down]

    @socket = nil
    
    @level_image = TexPlay.create_blank_image($window, $window.width, $window.height, :color => :black)
    @level = GameObject.create(:image => @level_image, :rotation_center => :top_left, :factor => $window.factor)
    @player = Player.create(:uuid => (rand * 100000).to_i, :factor => 4)
    @packet_counter = 0    
    
    connect_to_server
    
    send_data(@player.start_data)
    
    super
  end
    
  def connect_to_server
    puts "Connecting to #{@ip}:#{@port}"
    begin
      @socket = TCPSocket.new(@ip, @port)
      puts "Connected"
    rescue Errno::ECONNREFUSED
      exit
      puts "Couldn't connect, trying again in 3 seconds"
      sleep 3
      retry
    end
  end
  
  def send_data(data)
    @socket.puts(data.to_yaml)
  end
  
  
  def setup
  end
  def esc; exit; end
  
  def left
    @player.direction = :left
    send_data(@player.direction_data)
  end
  def right
    @player.direction = :right
    send_data(@player.direction_data)
  end
  def up
    @player.direction = :up
    send_data(@player.direction_data)
  end
  def down
    @player.direction = :down
    send_data(@player.direction_data)
  end
  
  def restart
    @level_image.rect(0,0, $window.width, $window.height, :color => :black, :fill => true)
  end
    
  def update
    super
    
    #connect_to_server if @socket.nil?
    
    if IO.select([@socket], nil, nil, 0.02)
      begin
        packet, sender = @socket.recvfrom(1000)
        
        begin
          data = YAML.load(packet)
          handle_data(data) if data
        rescue ArgumentError
          puts "bad yaml"
        end
      rescue Errno::ECONNABORTED
        puts "* Server disconnected"
        exit
      end
    end
        
    #
    #
    Player.each do |player|
      #@level_image.line player.previous_x, player.previous_y, player.x, player.y, :color => :white
      @level_image.pixel(player.x, player.y, :color => :white)
    end
    
    $window.caption = "Snake Online. [UUID: #{@player.uuid}] #{@player.x}/#{@player.y}. Packets recieved: #{@packet_counter} [FPS: #{$window.fps}]"
  end
    
  def handle_data(data)
    @packet_counter += 1
    
    p data  if data[:uuid] == @player.uuid && data[:cmd] == :position
    
    if data[:uuid]
      game_object = Player.find_by_uuid(data[:uuid]) || Player.create(data)
      case data[:cmd] 
        when :position 
          game_object.x = data[:x]
          game_object.y = data[:y]
        when :destroy
          puts "Destroy: #{game_object.uuid}"
          game_object.destroy
        when :kill
          puts "* Kill: #{game_object.uuid} died @ #{data[:x]}/#{data[:y]}"
          game_object.x = data[:x]
          game_object.y = data[:y]          
          game_object.alive = false
        end
    else
      case data[:cmd]
        when :ping
          send_data(@player.pong_data)
        when :restart
          puts "* Restart"
          restart          
      end
    end
  end
    
end

# If fils is executed, not required.
if __FILE__ == $0
  `netsnake.rbw`
end
