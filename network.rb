require 'socket'
#
# Common network code to send/read UDP networkdata.
# Depends on @socket
#
module Network

  def read_data
    if IO.select([@socket], nil, nil, 0)
      packet, sender = @socket.recvfrom(1000)
      data = Marshal.load(packet)
      #data = MessagePack.unpack(packet)
      return data, sender        
    end
  end
  
  def send_data(data)
    @socket.send(Marshal.dump(data), 0)
    #@socket.send(data.to_msgpack, 0)
  end  

  def game_object_by_uuid(uuid)
    Player.all.select { |game_object| game_object.uuid == uuid }.first
  end
  
end