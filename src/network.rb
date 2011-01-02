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
      return data, sender        
    end
  end
  
  def send_data(data)
    @socket.send(Marshal.dump(data), 0)
  end
  
end