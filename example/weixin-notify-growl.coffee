# Description:
#   check class schedule, then notify via message via weixin(wechat) and growl
#
# Dependencies:
#   node-growl
#
# Configuration:
#   HUBOT_GNTP_SERVER
#   HUBOT_GNTP_PASSWORD
#   HUBOT_WATCH_GROUPS          #群
#   HUBOT_WATCH_USERS           #用户
#   HUBOT_WATCH_GH              #公众号
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
  watchOpts =
    group: if process.env.HUBOT_WATCH_GROUPS then process.env.HUBOT_WATCH_GROUPS.split "," else []
    user: if process.env.HUBOT_WATCH_USERS then process.env.HUBOT_WATCH_USERS.split "," else []
    gh: if process.env.HUBOT_WATCH_GH then process.env.HUBOT_WATCH_GH.split "," else []

  #==============================
  # function
  #==============================
  check = (adapterName) ->
    if adapterName isnt "another-weixin"
      # check adapter
      robot.logger.error "[WARN] adapter should be another-weixin, but current is #{adapterName}, ignore"
      false
    true

  checkWatchGroup = (groupNickName) ->
    matched = false
    if groupNickName
      robot.logger.debug "[checkWatchGroup] groupNickName:", groupNickName
      for item, i in watchOpts.group
        if groupNickName is item
          matched = true
          break
    else
      robot.logger.error "[checkWatchGroup] groupNickName is invalid:", groupNickName
    matched

  checkWatchUser = (userInfo, isGH) ->
    matched = false
    filter = null
    if userInfo
      robot.logger.debug "[checkWatchUser] isGH:#{isGH} - KeyWord:#{userInfo['KeyWord']} RemarkName:#{userInfo.RemarkName} DisplayName:#{userInfo.DisplayName} NickName:#{userInfo.NickName}"
      if isGH
        filter = watchOpts.gh
      else
        filter = watchOpts.user
      for item, i in filter
        if userInfo.RemarkName and userInfo.RemarkName is item
          matched = true
          break
        else if userInfo.DisplayName and userInfo.DisplayName is item
          matched = true
          break
        else if userInfo.NickName and userInfo.NickName is item
          matched = true
          break
    else
      robot.logger.error "[checkWatchUser] isGH:#{isGH} - userInfo is invalid:", userInfo
    matched

  handleMessage = (text) ->
    xmlText = text.split("&lt;").join("<").split("&gt;").join(">").split("<br/>").join("\n")
    robot.logger.debug "xmlText:\n", xmlText
    xmlJson = {}
    xml2js.parseString xmlText, (err, result) ->
      if not err
        robot.logger.debug "handleMessage OK:", JSON.stringify(result, null, 2)
        xmlJson = result
      else
        robot.logger.error "handleMessage error:", err, " \nxmlText:\n", xmlText
    robot.logger.debug "xmlJson:\n", xmlJson
    return xmlJson


  robot.catchAll (resp) ->
    if not resp.message.text
      return
    robot.logger.debug "[WARN] not catched message:\nroom:#{resp.message.room}\nsender:#{resp.message.user.name}\nmessage:#{resp.message.text}"
    valid = check robot.adapterName
    if not valid
      return
    robot.logger.debug "[catchAll] receive message: #{resp.message}"
    groupNickName = ""
    fromUserName = resp.message.user.name
    fromUserInfo = null
    toUserInfo = null
    if not resp.message.user.room
      robot.logger.info "[room is empty] user: resp.message.user", resp.message.user
      fromNickName = robot.adapter.wxbot.getContactName fromUserName
      fromUserInfo = robot.adapter.wxbot.getContactByID fromUserName
      if fromUserInfo['KeyWord'] is "gh_"
        from = "[公众号]"
      else
        from = "From:"
      msgTitle = "From 微信[#{from}#{fromNickName}]"
    else if resp.message.user.room.substr(0, 2) is "@@"
      # group message
      _groupName = resp.message.user.room
      groupNickName = robot.adapter.wxbot.getGroupName _groupName
      fromNickName = robot.adapter.wxbot.getGroupMemberName _groupName, fromUserName
      isFriend = robot.adapter.wxbot.getContactName fromUserName
      if isFriend
        msgTitle = "From 微信[\##{groupNickName} #{fromNickName}]"
      else
        msgTitle = "From 微信[\##{groupNickName} (陌生人)#{fromNickName}]"
    else
      # direct message
      _toUserName = resp.message.user.room
      toNickName = robot.adapter.wxbot.getContactName _toUserName
      toUserInfo = robot.adapter.wxbot.getContactByID _toUserName
      fromNickName = robot.adapter.wxbot.getContactName fromUserName
      fromUserInfo = robot.adapter.wxbot.getContactByID fromUserName
      if fromUserInfo and fromUserInfo['KeyWord'] is "gh_"
        from = "公众号:"
      else
        from = "From:"
      if toUserInfo and toUserInfo['KeyWord'] is "gh_"
        to = "公众号:"
      else
        to = "To:"
      if not toNickName
        msgTitle = "From 微信[#{from}#{fromNickName} #{to}#{_toUserName}]"
      else
        msgTitle = "From 微信[#{from}#{fromNickName} #{to}#{toNickName}]"
    # parse message
    msgContent = resp.message.text
    url = ""
    if resp.message.text.match(/&lt;msg&gt;.*&lt;\/msg&gt;.*/) isnt null
      robot.logger.info "[xml message] start to parse..."
      msgJson = handleMessage resp.message.text
      if msgJson isnt null
        robot.logger.debug "\nmsgJson:", msgJson
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
      matched = false
      # filter message
      robot.logger.debug "watchOpts:", watchOpts, " groupNickName:", groupNickName, " fromUserInfo:", fromUserInfo, "toUserInfo:", toUserInfo
      if watchOpts.group.length > 0 and groupNickName
        robot.logger.info "filter 群名"
        matched = checkWatchGroup groupNickName
      else if watchOpts.user.length > 0 and fromUserInfo and fromUserInfo['KeyWord'] isnt "gh_"
        robot.logger.info "filter from:用户名"
        matched = checkWatchUser fromUserInfo, false
      else if watchOpts.user.length > 0 and toUserInfo and toUserInfo['KeyWord'] isnt "gh_"
        robot.logger.info "filter to:用户名"
        matched = checkWatchUser toUserInfo, false
      else if watchOpts.gh.length > 0 and fromUserInfo and fromUserInfo['KeyWord'] is "gh_"
        robot.logger.info "filter from:公众号"
        matched = checkWatchUser fromUserInfo, true
      else if watchOpts.gh.length > 0 and toUserInfo and toUserInfo['KeyWord'] is "gh_"
        robot.logger.info "filter to:公众号"
        matched = checkWatchUser toUserInfo, true
      else
        matched = true
      if matched
        robot.logger.info "Title: #{msgTitle} Content: #{msgContent}"
        _gntpOpts =
          server: gntpOpts.server
          password: gntpOpts.password
          appname: gntpOpts.appname
          url: url
        nodeGrowl msgTitle, msgContent, _gntpOpts, (text) ->
          if text isnt null
            robot.logger.warning ">gntp-send failed(#{text})"
          else
            robot.logger.info ">gntp-send OK"
      else
        robot.logger.info "Title: #{msgTitle} Content: #{msgContent}"
        robot.logger.warning "not matched message, skip send to growl"