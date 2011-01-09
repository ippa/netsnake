class Client < Chingu::GameState
    
  def initialize(options = {})
    #@ip = options[:ip] || "192.168.0.1"
    @ip = options[:ip] || "127.0.0.1"
    @port = 7778
    
    unless @ip
      puts "No serverIP given, please snart netsnake like this:"
      puts "ruby netsnake.rb <ip of server>"
      exit
    end
        
    self.input = [:esc, :left, :right, :up, :down]

    @socket = nil
    
    @level_image = TexPlay.create_blank_image($window, $window.width, $window.height, :color => :black)
    @level = GameObject.create(:image => @level_image, :rotation_center => :top_left, :factor => $window.factor, :zorder => 10)
    @player = Player.create(:uuid => (rand * 100000).to_i)
    @player.alive = false
    @packet_counter = 0    
    
    super
  end
    
  def connect_to_server
    begin
      $window.caption = "Connecting to #{@ip}:#{@port} ... "
      @socket = TCPSocket.new(@ip, @port)
      @socket.setsockopt(Socket::IPPROTO_TCP,Socket::TCP_NODELAY,1)
      send_data(@player.start_data)
    rescue Errno::ECONNREFUSED
      $window.caption = "Connecting to #{@ip}:#{@port} ... "
      sleep 2
      retry
    end
  end
  
  def send_data(data)
    @socket.puts(data.to_yaml)
  end
    
  def update
    super
    
    if @socket.nil?
      sleep 0.5
      connect_to_server
      return
    end
    
    if IO.select([@socket], nil, nil, 0.0)
      begin
        packet, sender = @socket.recvfrom(1000)
        #puts packet
        #puts "------"
        begin
          data = YAML.load(packet)
          handle_data(data) if data
        rescue ArgumentError
          puts "!! bad yaml !! #{packet}"
        end
      rescue Errno::ECONNABORTED
        puts "* Server disconnected"
        connect_to_server
      end
    end
        
    #
    #
    Player.alive.each do |player|
      #@level_image.line player.previous_x, player.previous_y, player.x, player.y, :color => :white
      @level_image.pixel(player.x, player.y, :color => player.color)
    end
    
    $window.caption = "Netsnake! #{@player.alive ? "Alive! :-) " : "Dead X-/"} [My UUID: #{@player.uuid}] [Players: #{Player.size}] [FPS: #{$window.fps}]"
  end
    
  def handle_data(data)
    @packet_counter += 1
    
    data = [data] if data.is_a? Hash
    data.each do |data|
    if data[:uuid]
      player = Player.find_by_uuid(data[:uuid]) || Player.create(data)
      
      case data[:cmd]
        when :winner
          if @player.uuid == data[:uuid]
            PuffText.create("YOU WON!")
          else
            PuffText.create("You LOST! #{data[:alias]||data[:uuid]} won.")
          end
        when :position
          player.x = data[:x]
          player.y = data[:y]
          player.color = data[:color]
          player.alive = true
        when :destroy
          puts "Destroy: #{player.uuid}"
          player.destroy
        when :kill
          puts "* Kill: #{player.uuid} died @ #{data[:x]}/#{data[:y]}"
          player.x = data[:x]
          player.y = data[:y] 
          player.alive = false
        end
    else
      case data[:cmd]
        when :ping
          send_data(@player.pong_data)
        when :restart
          puts "* Restart"
          Player.each { |player| player.alive = false }
          restart          
      end
    end
    end
  end

  def esc
    exit
  end
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
end


class PuffText < Text
  traits :timer, :effect, :velocity

  def initialize(text, options = {})    
    super(text, {:y => $window.height/2+50, :size => 30, :center_x => 0.5}.merge(options))
    self.x = ($window.width / 2)
    self.rotation_center = :center
    puff_effect
    self.zorder = 100
  end
  
  def puff_effect
    self.fade_rate = -1
    self.scale_rate = 0.01
    self.velocity_y = -1
    after(4000) { destroy }
  end
end

# If fils is executed, not required.
if __FILE__ == $0
  `netsnake.rbw`
end
