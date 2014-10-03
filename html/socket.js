
function Socket()
{
	var url = 'http://127.0.0.1:3600/socket';

	var sock = new SockJS(url);

	sock.onopen = function() {
		console.log('open');
	};
	sock.onmessage = function(e) {
		console.log(e);
		var jsonM = JSON.parse(e.data);
		console.log("Received message type is [" + jsonM.type + "]");
		console.log(jsonM);
		switch (jsonM.type) {

			case "newChatMessage":
			{
				$("#messages").append(
					"[" + jsonM.date + "]" + jsonM.name + ": " + jsonM.message);
				$("#messages").animate({ scrollTop: $(document).height() }, "fast");
				break;
			}
			case "updateRooms":
				var toAppend = "";
				jsonM.rooms.forEach(function(room) {
					toAppend += "<option>" + room + "</option>"
				});
				$("#rooms").html(toAppend);
		}
	};

	sock.onclose = function() {
		console.log('close');
	};

	this.send = function(message) {
		sock.send(message);

	};
}
