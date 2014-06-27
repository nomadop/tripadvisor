require 'faye'
Faye::WebSocket.load_adapter('thin')

app = Faye::RackAdapter.new(:mount => '/faye', :timeout => 25)
app.on(:handshake) do |cid|
	File.open("faye.log", "a+") do |file|
		file.puts "[#{Time.now}] client[#{cid}] connected."
	end
end
app.on(:disconnect) do |cid|
	File.open("faye.log", "a+") do |file|
		file.puts "[#{Time.now}] client[#{cid}] disconnected."
	end
end
app.on(:subscribe) do |cid, channel|
	File.open("faye.log", "a+") do |file|
		file.puts "[#{Time.now}] client[#{cid}] subscribed to channel '#{channel}'."
	end
end
app.on(:unsubscribe) do |cid, channel|
	File.open("faye.log", "a+") do |file|
		file.puts "[#{Time.now}] client[#{cid}] unsubscribed from channel '#{channel}'."
	end
end
app.on(:publish) do |cid, channel, data|
	File.open("faye.log", "a+") do |file|
		file.puts "[#{Time.now}] #{cid ? "client[#{cid}]" : 'server'} publish a message on channel '#{channel}': #{data}."
	end
end

run app