# Zoneminder live event integration into ia7 web interface

You need zmeventserver to enable zoneminder events to pop-up in your ia7 web
interface. You also have to add a new  zoneminder configuration section to your
ia7_config.json configuration file.

## ia7_config.json
Add the following section to ia7_config.json. It is possible to add multiple
Zoneminder servers.

    "zoneminder":
    [
    	{
    		"host": "zm.server",
    		"port": "9000",
    		"protocol": "ws",
    		"user": "yourusername",
    		"password": "yourpassword",
    		"scale": "50",
    		"timeout": 12000,
    		"debug": true,
    		"browsernotifications": true
    	}
    ]


`host:`
Hostname or IP of the server where zmeventserver instance is reachable.
Falls back to 'localhost' if omitted.

`port:`
Port zmeventserver is listening for web socket connections.
Falls back to '9000' if omitted.

`protocol:`
Web socket protocol to use. Set to "ws" for unencrypted connection or "wss" for a
secured connection.
Falls back to "wss" if omitted.

`user:`
Your zoneminder username.
Can be empty if zmeventserver has the the "noauth" configuration flag to '1'

`password:`
Your zoneminder password
Can be empty if zmeventserver has the the "noauth" configuration flag to '1'

`scale:`
Imager scale for the live image in percent.
Falls back to 100 if omitted

`timeout:`
Specifies how long the modal dialog for a zoneminder event is displayed in
milliseconds.
Falls back to 5500 if omitted

`debug:`
If set to 'true' verbose logging to the browser console is enabled.
Falls back to 'false' if omitted.

`browser notifications:`
enables in browser notifications about Zoneminder events. If enabled the ia7
will ask permission to enable notifications and pop-up a notification for each
event.

## zmeventserver
To enable zoneminder live events you need to setup zmeventserver on your
zoneminder instances. The original zmeventserver and its setup instructions can
be found at https://github.com/pliablepixels/zmeventserver

## Notes/ToDo
- for some setups it may be useful if we could ignore specific zm monitors
  because they produce to many events.
- It may be useful to disable zoneminder pop-ups entirely on specific
  parts of ia7 (e.g. if the site already displays your zoneminder monitors..)
