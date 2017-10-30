# Description:
#   check class schedule, then notify via message via weixin(wechat) and growl
#
# Dependencies:
#   node-growl
#
# Configuration:
#   HUBOT_GNTP_SERVER
#   HUBOT_GNTP_PASSWORD
#
# Commands:
#
#
# Author:
#   Jimmy Xu <xjimmyshcn@gmail.com>
#

nodeGrowl = require 'node-growl'
xml2js = require 'xml2js'

module.exports = (robot) ->

#==============================
# variable
#==============================
  gntpOpts =
    server: process.env.HUBOT_GNTP_SERVER
    password: process.env.HUBOT_GNTP_PASSWORD
    appname: "weixin-notify-growl"

  #==============================
  # function
  #==============================
  check = (adapterName) ->
    if adapterName isnt "another-weixin"
      # check adapter
      robot.logger.info "[WARN] adapter should be another-weixin, but current is #{adapterName}, ignore"
      false
    true

  handleMessage = (text) ->
    xmlText = text.split("&lt;").join("<").split("&gt;").join(">").split("<br/>").join("\n")
    console.log "xmlText:\n", xmlText
    xmlJson = {}
    xml2js.parseString xmlText, (err, result) ->
      if not err
        robot.logger.info "handleMessage OK:", JSON.stringify(result, null, 2)
        xmlJson = result
      else
        robot.logger.info "handleMessage error:", err
        null
    console.log "xmlJson:\n", xmlJson
    return xmlJson


  robot.catchAll (resp) ->
    if not resp.message.text
      return
    robot.logger.info "[WARN] not catched message:\nroom:#{resp.message.room}\nsender:#{resp.message.user.name}\nmessage:#{resp.message.text}"
    valid = check robot.adapterName
    if not valid
      return
    robot.logger.info "[catchAll] receive message: #{resp.message}"
    # parse user
    sendNickName = robot.adapter.wxbot.getContactName resp.message.user.name
    if not resp.message.user.room
      msgTitle = "From 微信[#{sendNickName}]"
    else if resp.message.user.room.substr(0, 2) is "@@"
      _groupName = resp.message.user.room
      groupNickName = robot.adapter.wxbox.getGroupName _groupName
      msgTitle = "From 微信[\##{groupNickName.NickName} #{sendNickName}]"
    else
      _toUserName = resp.message.user.room
      toNickName = robot.adapter.wxbot.getContactName _toUserName
      if not toNickName
        msgTitle = "From 微信[From:#{sendNickName} To:#{_toUserName}]"
      else
        msgTitle = "From 微信[From:#{sendNickName} To:#{toNickName}]"
    # parse message
    msgContent = resp.message.text
    url = ""
    if resp.message.text.match(/&lt;msg&gt;.*&lt;\/msg&gt;.*/) isnt null
      robot.logger.info "[xml message] start to parse..."
      msgJson = handleMessage resp.message.text
      if msgJson isnt null
        console.log "\nmsgJson:", msgJson
        if msgJson.msg.appmsg.length >= 1
          msgContent = "title:#{msgJson.msg.appmsg[0].title}\ndes:#{msgJson.msg.appmsg[0].des}"
          url = "#{msgJson.msg.appmsg[0].url}"
        else
          robot.logger.info "msgJson.msg.appmsg is empty:", msgJson.msg
    # notify message
    if gntpOpts.server
      robot.logger.info "title: #{msgTitle} message: #{msgContent}"
      _gntpOpts =
        server: gntpOpts.server
        password: gntpOpts.password
        appname: gntpOpts.appname
        url: url
      nodeGrowl msgTitle, msgContent, _gntpOpts, (text) ->
        robot.logger.info "gntp result: #{text}"
