# Pingpong Ruby client

This project contains a client for the [Reaktor Hello World Open event](http://helloworldopen.fi/).

NOTICE: The test server enforces a threshold of 10 messages per client in a second. At the moment the bot answers each message from the server with up direction message. This exceeds the threshold defined by the server and kicks the bot out of the game.

## Requires

[bundler](http://gembundler.com/)

Run `sudo gem install bundler` before building

## Installation

Run `build.sh`.

## Run the bot

Start the pingpong game bot with `start.sh <playername> <serverhostname>
<serverport>`.

Stop the bot with `stop.sh`.

## Credits

Copyright (C) 2012 Lauri Lehmijoki

Distributed under the Apache-2.0 license http://www.apache.org/licenses/LICENSE-2.0.html