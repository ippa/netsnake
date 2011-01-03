require 'socket'
#
# Common network code to send/read UDP networkdata.
# Depends on @socket
#
module Network

  def read_data
    if IO.select([@socket], nil, nil, 0)
      packet, sender = @socket.recvfrom(1000)
      if packet
        #puts "-> packet [#{packet.size}]"
        #data = Marshal.load(packet)
        #data = JSON.parse(packet)
        data = YAML.load(packet)
        return data, sender
      end
    end
  end
  
  def send_data(data)
    #@socket.send(Marshal.dump(data), 0)
    #@socket.send(data.to_json, 0)
    @socket.send(data.to_yaml, 0)
  end
  
end