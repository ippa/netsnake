class SyncNetwork < GameState
  trait :timer
  
  def setup
    Text.create("Client died, syncing network!", :size => 30)
    after(5000) { pop_game_state }
        
    previous_game_state.game_objects_of_class(Player).each do |player|
      player.unanswered_packets = 1
      previous_game_state.send_data_to_all({:cmd => :ping})
    end
  end
  
  def update
    
    begin
      data, sender = previous_game_state.read_data
      previous_game_state.handle_data(data, sender) if data
    rescue Errno::ECONNRESET => e
    end
    
    $window.caption = "Client died, syncing network!"
  end
  
  def finalize
    dead_uuids = []
    previous_game_state.game_objects_of_class(Player).each do |player|
      if player.unanswered_packets > 0 
        puts "#{player.uuid} didn't respond, destroying..."
        dead_uuids << player.uuid
        player.destroy
      end
    end
    
    dead_uuids.each do |dead_uuid|
      previous_game_state.send_data_to_all({:uuid => dead_uuid, :cmd => :destroy})
    end
  end
  
end