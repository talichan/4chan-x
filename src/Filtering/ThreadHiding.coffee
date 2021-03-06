ThreadHiding =
  init: ->
    return if g.VIEW is 'thread' or !Conf['Thread Hiding Buttons'] and !Conf['Thread Hiding Link'] and !Conf['JSON Navigation']
    @db = new DataBoard 'hiddenThreads'
    return @catalogWatch() if g.VIEW is 'catalog'
    @catalogSet g.BOARD
    Thread.callbacks.push
      name: 'Thread Hiding'
      cb:   @node

  catalogSet: (board) ->
    hiddenThreads = ThreadHiding.db.get
      boardID: board.ID
      defaultValue: {}
    hiddenThreads[threadID] = true for threadID of hiddenThreads
    localStorage.setItem "4chan-hide-t-#{board}", JSON.stringify hiddenThreads

  catalogWatch: ->
    @hiddenThreads = JSON.parse(localStorage.getItem "4chan-hide-t-#{g.BOARD}") or {}
    $.ready ->
      # 4chan's catalog sets the style to "display: none;" when hiding or unhiding a thread.
      new MutationObserver(ThreadHiding.catalogSave).observe $.id('threads'),
        attributes: true
        subtree: true
        attributeFilter: ['style']

  catalogSave: ->
    hiddenThreads2 = JSON.parse(localStorage.getItem "4chan-hide-t-#{g.BOARD}") or {}
    for threadID of hiddenThreads2 when !(threadID of ThreadHiding.hiddenThreads)
      ThreadHiding.db.set
        boardID:  g.BOARD.ID
        threadID: threadID
        val:      {makeStub: Conf['Stubs']}
    for threadID of ThreadHiding.hiddenThreads when !(threadID of hiddenThreads2)
      ThreadHiding.db.delete
        boardID:  g.BOARD.ID
        threadID: threadID
    ThreadHiding.hiddenThreads = hiddenThreads2

  node: ->
    if data = ThreadHiding.db.get {boardID: @board.ID, threadID: @ID}
      ThreadHiding.hide @, data.makeStub
    return unless Conf['Thread Hiding Buttons']
    $.prepend @OP.nodes.root, ThreadHiding.makeButton @, 'hide'

  onIndexBuild: (nodes) ->
    for root in nodes
      thread = Get.threadFromRoot root
      if thread.isHidden and thread.stub and !root.contains thread.stub
        ThreadHiding.makeStub thread, root
    return

  menu:
    init: ->
      return if g.VIEW isnt 'index' or !Conf['Menu'] or !Conf['Thread Hiding Link']

      div = $.el 'div',
        className: 'hide-thread-link'
        textContent: 'Hide thread'

      apply = $.el 'a',
        textContent: 'Apply'
        href: 'javascript:;'
      $.on apply, 'click', ThreadHiding.menu.hide

      makeStub = UI.checkbox 'Stubs', ' Make stub'

      Menu.menu.addEntry
        el: div
        order: 20
        open: ({thread, isReply}) ->
          if isReply or thread.isHidden or Conf['JSON Navigation'] and Conf['Index Mode'] is 'catalog'
            return false
          ThreadHiding.menu.thread = thread
          true
        subEntries: [el: apply; el: makeStub]

      div = $.el 'a',
        className: 'show-thread-link'
        textContent: 'Show thread'
        href: 'javascript:;'
      $.on div, 'click', ThreadHiding.menu.show 

      Menu.menu.addEntry
        el: div
        order: 20
        open: ({thread, isReply}) ->
          if isReply or !thread.isHidden or Conf['JSON Navigation'] and Conf['Index Mode'] is 'catalog'
            return false
          ThreadHiding.menu.thread = thread
          true

      hideStubLink = $.el 'a',
        textContent: 'Hide stub'
        href: 'javascript:;'
      $.on hideStubLink, 'click', ThreadHiding.menu.hideStub

      Menu.menu.addEntry
        el: hideStubLink
        order: 15
        open: ({thread, isReply}) ->
          if isReply or !thread.isHidden or Conf['JSON Navigation'] and Conf['Index Mode'] is 'catalog'
            return false
          ThreadHiding.menu.thread = thread

    hide: ->
      makeStub = $('input', @parentNode).checked
      {thread} = ThreadHiding.menu
      ThreadHiding.hide thread, makeStub
      ThreadHiding.saveHiddenState thread, makeStub
      $.event 'CloseMenu'

    show: ->
      {thread} = ThreadHiding.menu
      ThreadHiding.show thread
      ThreadHiding.saveHiddenState thread
      $.event 'CloseMenu'

    hideStub: ->
      {thread} = ThreadHiding.menu
      ThreadHiding.show thread
      ThreadHiding.hide thread, false
      ThreadHiding.saveHiddenState thread, false
      $.event 'CloseMenu'
      return

  makeButton: (thread, type) ->
    a = $.el 'a',
      className: "#{type}-thread-button"
      href:      'javascript:;'
    $.extend a, <%= html('<span class="fa fa-${(type === "hide") ? "minus" : "plus"}-square"></span>') %>
    a.dataset.fullID = thread.fullID
    $.on a, 'click', ThreadHiding.toggle
    a
  makeStub: (thread, root) ->
    numReplies  = $$('.thread > .replyContainer', root).length
    numReplies += +summary.textContent.match /\d+/ if summary = $ '.summary', root
    opInfo = if Conf['Anonymize']
      'Anonymous'
    else
      $('.nameBlock', thread.OP.nodes.info).textContent

    a = ThreadHiding.makeButton thread, 'show'
    $.add a, $.tn " #{opInfo} (#{if numReplies is 1 then '1 reply' else "#{numReplies} replies"})"
    thread.stub = $.el 'div',
      className: 'stub'
    if Conf['Menu']
      $.add thread.stub, [a, Menu.makeButton thread.OP]
    else
      $.add thread.stub, a
    $.prepend root, thread.stub

  saveHiddenState: (thread, makeStub) ->
    if thread.isHidden
      ThreadHiding.db.set
        boardID:  thread.board.ID
        threadID: thread.ID
        val: {makeStub}
    else
      ThreadHiding.db.delete
        boardID:  thread.board.ID
        threadID: thread.ID
    ThreadHiding.catalogSet thread.board

  toggle: (thread) ->
    unless thread instanceof Thread
      thread = g.threads[@dataset.fullID]
    if thread.isHidden
      ThreadHiding.show thread
    else
      ThreadHiding.hide thread
    ThreadHiding.saveHiddenState thread

  hide: (thread, makeStub=Conf['Stubs']) ->
    return if thread.isHidden
    threadRoot = thread.OP.nodes.root.parentNode
    thread.isHidden = true
    Index.updateHideLabel() if Conf['JSON Navigation']

    return threadRoot.hidden = true unless makeStub

    ThreadHiding.makeStub thread, threadRoot

  show: (thread) ->
    if thread.stub
      $.rm thread.stub
      delete thread.stub
    threadRoot = thread.OP.nodes.root.parentNode
    threadRoot.hidden = thread.isHidden = false
    Index.updateHideLabel() if Conf['JSON Navigation']
