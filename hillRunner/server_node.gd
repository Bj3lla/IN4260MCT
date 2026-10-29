# server_node.gd
#IMPORTANT! ServerScript should only be added once. Currently only in accel_input.gd
# If added more than one place multiple sockets will fight over the same port (4242). 
class_name ServerScript 
extends Node

var udp := PacketPeerUDP.new()


signal update_IMU(vectors : Array) #motion: accelleration xyz, and quaternion wxyz. Delivers [ax, ay, az, qw, qx, qy, qz]
signal update_HRT(hr : Array) #heartrate 4 bytes: 1st float is heartrate, 2nd byte is deviation
#PPG_Channel = 'g' (green). Green is usually the cleanest at the wrist

# always uses the same port, might be fine
func _ready():
	var error := udp.bind(4242)
	if error == OK:
		print("UDP bound successfully to port 4242")
	else:
		print("Failed to bind UDP socket: ", error)

func _process(delta):
	if udp.get_available_packet_count() > 0:
		var packet : PackedByteArray = udp.get_packet()
		unpack_data(packet)

# ugly, this might drop a lot of packages and make motions rough?
func unpack_data(bytes: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	var string_bytes = buffer.get_data(3)
	
	if string_bytes[0] != OK:
		print("Error reading string bytes")
		return
	var my_string = string_bytes[1].get_string_from_utf8()
	if my_string == "HRT":
		var current_hr = buffer.get_float()
		var current_dv = buffer.get_float()
		var signal_buf = [current_hr, current_dv]
		print("HRT")
		print(current_hr)
		update_HRT.emit(signal_buf)
		
	elif  my_string == "IMU":
		var buf : Array = []
		for i in range(7):
			buf.append(buffer.get_float())

		print("IMU")
		print(buf)
		update_IMU.emit(buf)
