# Description:
#   check class schedule, then notify via message via weixin(wechat) and growl
#
# Dependencies:
#   node-growl
#
# Configuration:
#   HUBOT_EXT_CMD_BIN
#   HUBOT_EXT_CMD_ARG
#   HUBOT_CHECK_INTERVAL
#   HUBOT_TARGET_NICKNAME
#   HUBOT_TARGET_REMARKNAME
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

module.exports = (robot) ->

#==============================
# variable
#==============================
  gntpOpts =
    server: process.env.HUBOT_GNTP_SERVER
    password: process.env.HUBOT_GNTP_PASSWORD
    appname: "schedule-monitor"
  cmdOpts =
    bin: process.env.HUBOT_EXT_CMD_BIN
    arg: process.env.HUBOT_EXT_CMD_ARG
  targetOpts =
    nickName: process.env.HUBOT_TARGET_NICKNAME
    remarkName: process.env.HUBOT_TARGET_REMARKNAME
  interval = if process.env.HUBOT_CHECK_INTERVAL then process.env.HUBOT_CHECK_INTERVAL else 15
  targetUser = null
  scheduleResult =
    NotChanged: "课程无变化"
    Error: "程序错误"
    Changed: null

  #==============================
  # function
  #==============================
  run_cmd = (cmd, args, cb) ->
    console.debug "[schedule-monitor] spawn:", cmd, args
    spawn = require("child_process").spawn
    child = spawn(cmd, args)
    result = []
    child.stdout.on "data", (buffer) -> result.push buffer.toString()
    child.stderr.on "data", (buffer) -> result.push buffer.toString()
    child.stdout.on "end", -> cb result

  check = (adapterName, sender) ->
    if adapterName isnt "another-weixin"
    # check adapter
      robot.logger.info "[WARN] adapter should be another-weixin, but current is #{adapterName}, ignore"
      false

    # find target user
    if not targetUser
      targetUsers = robot.adapter.wxbot.getContactByName(targetOpts.remarkName, targetOpts.nickName)
      if targetUsers.length isnt 1
        robot.logger.info "[WARN] target user must be unique: #{targetUsers.length}), ignore"
        false
      targetUser = targetUsers[0]
      robot.logger.info "found target user: #{targetUser.UserName}, #{targetUser.NickName}"

    # check sender
    sendNickName = robot.adapter.wxbot.getContactName sender
    if not sendNickName
      robot.logger.info "[WARN] sender(#{sender}) not found, ignore"
      false
    robot.logger.info "found send user: #{sendNickName} - (#{sender})"
    if sender not in [ targetUser.UserName, robot.adapter.wxbot.myUserName ]
      robot.logger.info "[WARN] sender isn't valid, ignore"
      false
    true


  setTimer = (_interval) ->
    if _interval is 0
      # find target user
      targetUsers = robot.adapter.wxbot.getContactByName(targetOpts.remarkName, targetOpts.nickName)
      if targetUsers.length isnt 1
        robot.logger.info "[WARN] target user must unique: #{targetUsers.length}), ignore"
        false
      targetUser = targetUsers[0]
      robot.logger.info "found target user: #{targetUser.UserName}, #{targetUser.NickName}"

      msgContent="#{robot.name}: 开始监控课表"
      robot.adapter.wxbot.api.sendMessage robot.adapter.wxbot.myUserName, targetUser.UserName, msgContent, (rlt) ->
        robot.logger.info "start message had been sent to #{targetUser.NickName}: #{rlt.statusMessage}(#{rlt.statusCode})"

    setTimeout doFetch, _interval * 60 * 1000, ((e, result) ->
      if e
        robot.logger.info "[doFetch] result: #{e}"
      else
        msgTitle = "schedule fetched"
        msgContent = "#{robot.name}: #{result}"
        robot.logger.info "msgTitle: #{msgTitle} msgContent: #{msgContent}"
        # notify via wechat
        if targetUser.UserName
          robot.adapter.wxbot.api.sendMessage robot.adapter.wxbot.myUserName, targetUser.UserName, msgContent, (rlt) ->
            robot.logger.info "result had been sent to #{targetUser.NickName}: #{rlt.statusMessage}(#{rlt.statusCode})"
        else
          robot.logger.info "[WARN] skip to send message to wechat"
        if gntpOpts.server
          # notify via gntp-send
          robot.logger.info "title: #{msgTitle} message: #{msgContent} gntpOpts: #{gntpOpts}"
          nodeGrowl msgTitle, msgContent, gntpOpts, (text) ->
            robot.logger.info "gntp result: #{text}"
        else
          robot.logger.info "[WARN] skip to send message to growl"
    ), (() ->
      robot.logger.info "result had been sent, check again after #{interval} minutes"
      setTimer interval
    )

  doFetch = (callback, onFinish) ->
    robot.logger.info "Check it!"
    run_cmd cmdOpts.bin, cmdOpts.arg.split(" "), (result) ->
      robot.logger.info "[run_cmd] result: #{result}"
      result = result.join("")
      if not result
        callback scheduleResult.NotChanged, ""
      else
        callback scheduleResult.Changed, result
      if onFinish
        onFinish()

  #==============================
  # main
  #==============================

  # start monitor task
  setTimer 0

  robot.respond /ping/i, (resp) ->
    valid = check robot.adapterName, resp.message.user.name
    if not valid
      return
    robot.logger.info "[ping] pass check"
    result = "#{robot.name}: pong"
    # send to growl
    _msgTitle = "sender:#{resp.message.user.name} - ping"
    nodeGrowl _msgTitle, result, gntpOpts, (text) ->
      if text isnt null
        robot.logger.info ">[sender:#{resp.message.user.name}] gntp-send failed(#{text})"
      robot.logger.info ">gntp-send OK"
    # send to wechat
    if robot.adapter.wxbot.myUserName is resp.message.user.name
      robot.adapter.wxbot.api.sendMessage robot.adapter.wxbot.myUserName, "filehelper", result, (rlt) ->
        robot.logger.info "send to filehelper: #{rlt.statusMessage}(#{rlt.statusCode})"
    else
      robot.logger.info "reply to sender #{resp.message.user.name}"
      resp.reply result


  robot.respond /课表/i, (resp) ->
    valid = check robot.adapterName, resp.message.user.name
    if not valid
      return
    robot.logger.info "[课表] pass check"
    #fetch schedule
    run_cmd cmdOpts.bin, cmdOpts.arg.split(" "), (result) ->
      robot.logger.info "result:#{result}"
      result = result.join("")
      if not result
        result = "课表无变更"
      # send to growl
      _msgTitle = "sender:#{resp.message.user.name} - 课表"
      result = "#{robot.name}: #{result}"
      nodeGrowl _msgTitle, result, gntpOpts, (text) ->
        if text isnt null
          robot.logger.info ">[sender:#{resp.message.user.name}] gntp-send failed(#{text})"
        robot.logger.info ">gntp-send OK"
      # send to wechat
      if robot.adapter.wxbot.myUserName is resp.message.user.name
        robot.adapter.wxbot.api.sendMessage robot.adapter.wxbot.myUserName, "filehelper", result, (rlt) ->
          robot.logger.info "send to filehelper: #{rlt.statusMessage}(#{rlt.statusCode})"
      else
        robot.logger.info "reply to sender #{resp.message.user.name}"
        resp.reply result


  #  robot.listen(
  #    (msg) ->
  #      if not msg
  #        robot.logger.info "[WARN] msg is empty"
  #        return false
  #      valid = check robot.adapterName, resp.message.user.name
  #      robot.logger.info "[listen:msg] hubot adapter is #{robot.adapterName}, receive msg:#{msg} - valid:#{valid}"
  #      return valid
  #    (resp) ->
  #      robot.logger.info "[listen:resp] sender:#{resp.message.user.name} message:#{resp.message.text}"
  #  )

  robot.catchAll (resp) ->
    if not resp.message.text
      return
    robot.logger.info "[WARN] not catched message: sender:#{resp.message.user.name} message:#{resp.message.text}"
    valid = check robot.adapterName, resp.message.user.name
    if not valid
      return
    robot.logger.info "[catchAll] pass check"