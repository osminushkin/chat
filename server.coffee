express			= require "express"
sockjs			= require 'sockjs'
http			= require 'http'
mongoose		= require "mongoose"
cookieParser	= require 'cookie-parser'
randomstring	= require "randomstring"
users = []
# ===========================================================
mongoose.connect "mongodb://localhost/chat"
mongoose.connection.on "error", (err) ->
	console.error "connection error: #{err.message}"
	process.exit()
mongoose.connection.once "open", () ->
	console.log "Connected to DB!"

UserSchema = new mongoose.Schema {login: String,password: String}
MessageSchema = new mongoose.Schema {date:Date,user:String,message:String,room:String,createdAt:{type:Date,expires:60*5}}
RoomSchema = new mongoose.Schema {room:String}
UserModel = mongoose.model 'UserModel', UserSchema
MessageModel = mongoose.model 'MessageModel', MessageSchema
RoomModel = mongoose.model 'RoomModel', RoomSchema
# ===========================================================
app = express()
app.all '*', (req, res, next) ->
	res.set 'Access-Control-Allow-Origin', '*'
	next()
app.use express.static "#{__dirname}/html"
app.set 'views', "#{__dirname}/html"
app.set 'view engine', 'ejs'
app.use cookieParser()
app.use (req, res, next) ->
	data = ''
	req.setEncoding 'utf8'
	req.on 'data', (chunk) ->
		data += chunk
	req.on 'end', () ->
		req.rawBody = data
		next()
app.get "/login.html", (req, res) ->
	res.render "login", {message: ""}
app.post "/login", (req, res) ->

	generateUserIdAndSendItToClient = (user) ->
		userId = randomstring.generate()
		console.log "Generated userId for user #{user.login} (#{userId})"
		userItem = {login: user.login, userId: userId, conn: null, selectedRoom: null, isAuthenticated: false}
		users.push userItem
		setTimeout () ->
			index = users.indexOf userItem
			if not users[index].conn? or users[index].conn.readyState is 3
				console.log "userId time is out (#{userId})"
				users.splice index, 1
		, 60*60*1000
		res.cookie "userId", userId
		res.redirect 301, "/"

	params = []
	(req.rawBody.split "&").forEach (pair) ->
		pairSplited = pair.split "="
		params[pairSplited[0]] = pairSplited[1]
	login = params["login"]
	password = params["password"]
	commit = params["commit"]

	if (login.search /^[0-9A-Za-z_\-\(\)\[\]\.]{3,}$/) is -1 or
	(password.search /^[0-9A-Za-z]{3,}$/) is -1 or
	(commit isnt "Register" and commit isnt "Login")
		res.render "login", {message: "Something wrong in request, try again please"}
		return

	if commit is "Register"
		console.log "Register new user (#{login}:#{password})"
		newUser = new UserModel {login: login, password: password}
		newUser.save (err, user) ->
			if err? or not user?
				console.log "DB operation failed"
				res.render "login.ejs", {message: "DB operation failed, please try again"}
				return
			generateUserIdAndSendItToClient user
	else if commit is "Login"
		console.log "Received login request (#{login}:#{password})"
		UserModel.findOne {login: login, password: password}, (err, user) ->
			if err? or not user?
				res.render "login", {message: "The login/password you provided not found in DB. Probably you are not registered yet."}
				return
			generateUserIdAndSendItToClient user

socket = sockjs.createServer()
socket.on 'connection', (conn) ->

	tm = setTimeout () ->
		console.log "Authentication not passed in 5 seconds after connection established. Connection will be closed"
		conn.write JSON.stringify {	type: "redirect", url: "login.html" }
		conn.close()
	, 5000

	conn.on 'data', (message) ->

		console.log message
		jsonM = JSON.parse message
		if not jsonM.userId?
			console.log "Received message with undefined userId"
			conn.write JSON.stringify {	type: "redirect", url: "login.html" }

		user = getUserByUserId jsonM.userId

		if jsonM.type is "authentication"
			clearTimeout tm

			if user?
				users[users.indexOf user].conn = conn
				users[users.indexOf user].isAuthenticated = true

				RoomModel.find {}, (err, rooms) ->
					roomsNameArray = rooms.map (room) ->
						room.room

					conn.write JSON.stringify {	type: "updateRooms", rooms: roomsNameArray }
			else
				console.error "Authentication message received from not authorized user"
				conn.write JSON.stringify {	type: "redirect", url: "login.html" }

			return

		if user.isAuthenticated
			switch jsonM.type
				when "newChatMessage"
					console.log "new chat message in room #{jsonM.room}"
					users.forEach (tmpUser) ->
						if tmpUser.isAuthenticated and (tmpUser.selectedRoom is jsonM.room) and (tmpUser.conn.readyState is 1)
							tmpUser.conn.write JSON.stringify {
								type: "newChatMessage",
								user: user.login,
								message: jsonM.message,
								date: jsonM.date,
								room: jsonM.room
							}
					
					newMessage = {user: user.login, message: jsonM.message, date: jsonM.date, room: jsonM.room, createdAt: Date.now()}
					newMessageModel = new MessageModel newMessage
					newMessageModel.save (err, message) ->
						if err?
							console.error "Failed to store new message"
				when "newChatRoom"
					console.log "new chat room #{jsonM.room}"
					newRoom = new RoomModel {room: jsonM.room}
					newRoom.save (err, room) ->
						if err?
							console.error "Failed to store new room in DB"

					users.forEach (tmpUser) ->
						if tmpUser.isAuthenticated and tmpUser.conn.readyState is 1
							tmpUser.conn.write JSON.stringify {type: "newChatRoom", room: jsonM.room}
				when "selectChatRoom"
					users[users.indexOf user].selectedRoom = jsonM.room
					MessageModel.find {room: jsonM.room}, 'date user message', (err, messages) ->
						if err?
							console.error "Failed to get messages from DB for #{jsonM.room} room"
						user.conn.write JSON.stringify {type: "loadRoomMessages", room: jsonM.room, messages: messages}

	conn.on 'close', () ->
		console.log "Closed"


server = http.createServer app
socket.installHandlers server, {prefix:'/socket'}
server.listen 3600
console.log "[fmmodule] listening port " + 3600

getUserByUserId = (userId) ->
	user = undefined
	for tmpUser in users
		if tmpUser.userId is userId
			user = tmpUser
			break
	return user