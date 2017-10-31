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
    console.debug "xmlText:\n", xmlText
    xmlJson = {}
    xml2js.parseString xmlText, (err, result) ->
      if not err
        console.debug "handleMessage OK:", JSON.stringify(result, null, 2)
        xmlJson = result
      else
        robot.logger.info "handleMessage error:", err, " \nxmlText:\n", xmlText
    console.debug "xmlJson:\n", xmlJson
    return xmlJson


  robot.catchAll (resp) ->
    if not resp.message.text
      return
    console.debug "[WARN] not catched message:\nroom:#{resp.message.room}\nsender:#{resp.message.user.name}\nmessage:#{resp.message.text}"
    valid = check robot.adapterName
    if not valid
      return
    console.debug "[catchAll] receive message: #{resp.message}"
    if not resp.message.user.room
      _fromUserName = resp.message.user.name
      fromNickName = robot.adapter.wxbot.getContactName _fromUserName
      console.log "[room is empty] user: resp.message.user", resp.message.user
      msgTitle = "From 微信[#{fromNickName}]"
    else if resp.message.user.room.substr(0, 2) is "@@"
      _groupName = resp.message.user.room
      groupName = robot.adapter.wxbot.getGroupName _groupName
      _fromUserName = resp.message.user.name
      fromNickName = robot.adapter.wxbot.getGroupMemberName _groupName, _fromUserName
      isFriend = robot.adapter.wxbot.getContactName _fromUserName
      if isFriend
        msgTitle = "From 微信[\##{groupName} #{fromNickName}]"
      else
        msgTitle = "From 微信[\##{groupName} (陌生人)#{fromNickName}]"
    else
      _fromUserName = resp.message.user.name
      _toUserName = resp.message.user.room
      fromNickName = robot.adapter.wxbot.getContactName _fromUserName
      toNickName = robot.adapter.wxbot.getContactName _toUserName
      if not toNickName
        msgTitle = "From 微信[From:#{fromNickName} To:#{_toUserName}]"
      else
        msgTitle = "From 微信[From:#{fromNickName} To:#{toNickName}]"
    # parse message
    msgContent = resp.message.text
    url = ""
    if resp.message.text.match(/&lt;msg&gt;.*&lt;\/msg&gt;.*/) isnt null
      robot.logger.info "[xml message] start to parse..."
      msgJson = handleMessage resp.message.text
      if msgJson isnt null
        console.debug "\nmsgJson:", msgJson
        if msgJson.msg.appmsg and msgJson.msg.appmsg.length >= 1
          msgContent = "[链接] 标题:#{msgJson.msg.appmsg[0].title}\n摘要:#{msgJson.msg.appmsg[0].des}"
          url = "#{msgJson.msg.appmsg[0].url}"
        else if msgJson.msg.img and msgJson.msg.img.length >= 1
          img = msgJson.msg.img[0]['$']
          size = Math.round parseInt(img.length) / 1024
          msgContent = "[图片] 宽:#{img.cdnthumbwidth}像素 高:#{img.cdnthumbheight}像素 大小:#{size}KB"
        else if msgJson.msg.voicemsg and msgJson.msg.voicemsg.length >= 1
          voice = msgJson.msg.voicemsg[0]['$']
          voicelength = Math.round parseInt(voice.voicelength) / 1000
          size = Math.round parseInt(voice.length) / 1024
          msgContent = "[语音] length:#{voicelength} 秒 大小:#{size}KB"
        else if msgJson.msg.videomsg and msgJson.msg.videomsg.length >= 1
          video = msgJson.msg.videomsg[0]['$']
          size = Math.round parseInt(video.length) / 1024
          msgContent = "[视频] length:#{video.playlength} 秒 大小:#{size}KB"
        else
          other = Object.keys msgJson.msg
          msgContent = "[未解析]#{other}\n#{JSON.stringify(msgJson, null, 2)}"
          robot.logger.info "key of msgJson.msg:", other
    else if resp.message.text.match(/&lt;msg .*\/&gt;/) isnt null
      robot.logger.info "[xml message:名片] start to parse..."
      msgJson = handleMessage resp.message.text
      card = msgJson.msg['$']
      gender = if card.sex is "1" then "男" else "女"
      msgContent = "[名片] 用户名:#{card.username} 昵称:#{card.nickname} 城市:#{card.city} 省:#{card.province} 性别:#{gender}"
    else if resp.message.text.match(/webwxgetpubliclinkimg.*pictype=location/) isnt null
      robot.logger.info "共享位置:", resp.message.text
      position = resp.message.text.split(':<br/>')[0]
      msgContent = "[共享位置]#{position}"
    # notify message
    if gntpOpts.server
      robot.logger.info "title: #{msgTitle} message: #{msgContent}"
      _gntpOpts =
        server: gntpOpts.server
        password: gntpOpts.password
        appname: gntpOpts.appname
        url: url
      nodeGrowl msgTitle, msgContent, _gntpOpts, (text) ->
        if text isnt null
          robot.logger.info ">gntp-send failed(#{text})"
        else
          robot.logger.info ">gntp-send OK"
