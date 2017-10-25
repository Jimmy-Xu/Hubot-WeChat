try
  {Robot, Adapter, TextMessage, User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot, Adapter, TextMessage, User} = prequire 'hubot'

# node.js deps
jsons = JSON.stringify
# npm deps

# app deps
WxBot = require "../src/wxbot"
config = require '../src/config'
log = require '../src/wxLog'
NanoTimer = require 'nanotimer'

class WxBotAdapter extends Adapter

  constructor: (robot) ->
    super
    @robot.logger.info "Construct Robot"
    @robot = robot
    @webWxSyncTimer = new NanoTimer()
    @syncCheckTimer = new NanoTimer()
    @healthCheckTimer = new NanoTimer()

  send: (envelope, strings...) ->
    @robot.logger.info "hubot is sending #{strings}"
    if envelope.hasOwnProperty "user"
      toGroup = envelope.user.room
      toUser = envelope.user.name
    else if envelope.hasOwnProperty "room" # To support robot.messageRoom
      toGroup = envelope.room

    for string in strings
      @wxbot.sendMessage @wxbot.myUserName, toGroup, toUser, string, (resp, resBody, opts) ->
        log.debug "sendToUser", jsons resBody

  reply: (envelope, strings...) ->
    @robot.logger.info "hubot is repling #{strings}"
    @send envelope, strings...

  emote: (envelope, strings...) ->
    if envelope.hasOwnProperty "user"
      toGroup = envelope.user.room
      toUser = envelope.user.name
    else if envelope.hasOwnProperty "room" # To support robot.messageRoom
      toGroup = envelope.room
    for string in strings
      # the string is a file path of media to be sent
      @wxbot.webWxUploadAndSendMedia @wxbot.myUserName, toGroup, toUser, string

  run: ->
    self = @
    @robot.logger.info "WxHubot Staring Running"
    @wxbot = new WxBot()
    @wxbot.getInit()
    @wxbot.updateGroupList()
    @wxbot.updateGroupMemberList()
    @wxbot.registerHubotReceiveFn @hubotReceiveMsgFn
    @emit 'connected'
    @robot.logger.info "wx robot init done"
    _contactList = []
    for userName, c of @wxbot.contactInfo
      _contactList.push c.NickName + "(" + userName + ")"
    log.debug "@contactInfo", _contactList
    log.debug "@groupInfo", Object.keys(@wxbot.groupInfo).length
    log.debug "@groupMemberInfo", Object.keys(@wxbot.groupMemberInfo).length
    @webWxSyncTimer.setInterval @wxbot.webWxSync, '', config.webWxSyncInterval
    @syncCheckTimer.setInterval @wxbot.syncCheck, '', config.syncCheckInterval
    @healthCheckTimer.setInterval @wxbot.reportHealthToMaintainer, '', config.reportHealthInterval

    @_quitProcessOnException()

  hubotReceiveMsgFn: (groupName, userName, content, msgId) =>
    user = new User userName, {room: groupName}
    @receive new TextMessage user, content, msgId

  _quitProcessOnException: () ->
    process.on 'uncaughtException', (err) =>
      @webWxSyncTimer.clearInterval()
      @syncCheckTimer.clearInterval()
      @healthCheckTimer.clearInterval()
      log.critical "caught an exception, #{err}! Process exit code: 2"
      process.exit 2

exports.use = (robot) ->
  new WxBotAdapter robot