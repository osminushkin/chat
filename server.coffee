express		= require "express"
sockjs		= require 'sockjs'
http    	= require 'http'
mongoose 	= require "mongoose"

mongoose.connect "mongodb://localhost/chat"

mongoose.connection.on "error", (err) ->
	console.error "connection error: #{err.message}"
	process.exit()
mongoose.connection.once "open", () ->
	console.log "Connected to DB!"

UserSchema = new mongoose.Schema {
	login: String,
	password: String
}

UserModel = mongoose.model 'UserModel', UserSchema

MessageSchema = new mongoose.Schema {
	date: Date,
	user: String,
	message: String,
	room: String,
	CreatedAt: {type: Date, expires: 60*5}
}

MessageModel = mongoose.model 'MessageModel', MessageSchema

RoomSchema = new mongoose.Schema {
	roomName: String
}

RoomModel = mongoose.model 'RoomModel', RoomSchema

app = express()
app.all '*', (req, res, next) ->
    res.set 'Access-Control-Allow-Origin', '*'
    next()
app.use(express.static(__dirname + '/html'));

socket = sockjs.createServer()

userId = 0
users = []

socket.on 'connection', (conn) ->

	RoomModel.find {}, (err, rooms) ->
		roomsNameArray = rooms.map (room) ->
			room.roomName

		conn.write JSON.stringify {	type: "updateRooms", rooms: roomsNameArray }

	users.push {conn: conn, selectedRoom: ""}

	conn.on 'data', (message) ->

		console.log message
		jsonM = JSON.parse message

		switch jsonM.type
			when "newChatMessage"
				console.log "new chat message in room " + jsonM.room
				users.forEach (user) ->
					if user.selectedRoom is jsonM.room
						user.conn.write message
		#when "selectRoom"



	conn.on 'close', () ->
		console.log "Closed"


server = http.createServer app

socket.installHandlers server, {prefix:'/socket'}

server.listen 3600
console.log "[fmmodule] listening port " + 3600