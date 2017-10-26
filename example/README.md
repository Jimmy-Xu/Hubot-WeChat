example to use hubot-another-weixin
===================================

This script will run periodic task which specified by HUBOT_EXT_CMD_BIN and HUBOT_EXT_CMD_ARG) every HUBOT_CHECK_INTERVAL.
The return message will be send via gntp-send and wechat.
The target wechat user is specified by HUBOT_TARGET_NICKNAME and HUBOT_TARGET_REMARKNAME.
The gntp server is specified by HUBOT_GNTP_SERVER and HUBOT_GNTP_PASSWORD.

# create hubot

```bash
$ npm install -g coffee-script
$ npm install -g yo generator-hubot
$ mkdir ~/hubot
$ cd ~/hubot
$ yo hubot

$ npm install hubot-another-weixin
$ cp node_modules/hubot-another-weixin/example/schedule-monitor.coffee scripts/
```

# get wechat arguments

## login https://wx.qq.com

get Cookie(Request Headers) and BaseRequest(Request Payload) from browser debug console.
for example, from chrome

![](webwxinit.png)


## start hubot with another-weixin adapter
```bash
export HUBOT_TARGET_NICKNAME="xxx"
export HUBOT_TARGET_REMARKNAME="xxx"
export HUBOT_CHECK_INTERVAL="15"
export HUBOT_EXT_CMD_BIN="/home/xjimmy/gopath/src/github.com/jimmy-xu/talk915/main"
export HUBOT_EXT_CMD_ARG="--username xxxxxxxxx --password=xxxxxxxxxxx --period=0 --quiet"
export HUBOT_GNTP_SERVER="192.168.1.23"
export HUBOT_GNTP_PASSWORD="xxxxxxxx"
./bin/hubot -n "mybot" -a another-weixin
```
