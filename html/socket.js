
function Socket()
{
	var url = 'http://127.0.0.1:3600/socket';

	var sock = new SockJS(url);

	sock.onopen = function() {
		console.log('open');
		sock.send(JSON.stringify({
			type: "authentication",
			userId:getCookieUserId()
		}));
	};
	sock.onmessage = function(e) {
		console.log(e);
		var jsonM = JSON.parse(e.data);
		console.log("Received message type is [" + jsonM.type + "]");
		console.log(jsonM);
		switch (jsonM.type) {

			case "newChatMessage":
			{
				if ($("#rooms option:selected").text() === jsonM.room) {
					$("#messages").append("[" + jsonM.date + "]" + jsonM.user + ": " + jsonM.message);
					$("#messages").animate({ scrollTop: $(document).height() }, "fast");
				}
				break;
			}
			case "updateRooms":
				var toAppend = "";
				jsonM.rooms.forEach(function(room) {
					toAppend += "<option>" + room + "</option>"
				});
				$("#rooms").html(toAppend);
				break;
			case "newChatRoom":
				$("#rooms").append("<option>" + jsonM.room + "</option>");
				break;
			case "loadRoomMessages":
				var toAppend = "";
				jsonM.messages.forEach(function(message) {
					toAppend += "[" + message.date + "]" + message.user + ": " + message.message;
				});
				$("#messages").html(toAppend);
				$("#messages").animate({ scrollTop: $(document).height() }, "fast");
				break;
			case "redirect":
				window.location.pathname = jsonM.url;
		}
	};

	sock.onclose = function() {
		console.log('close');
	};

	this.send = function(message) {
		sock.send(message);

	};
}
