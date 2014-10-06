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
RoomSchema = new mongoose.Schema {roomName:String}
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
		users.push {login: user.login, conn: null, selectedRoom: null, isAuthenticated: false}
		res.cookie "userId", userId
		res.redirect 301, "/"

	console.log req.rawBody
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
		console.log "Authentification not passed in 5 seconds after connection established. Connection will be closed"
		conn.close()
	, 5000



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