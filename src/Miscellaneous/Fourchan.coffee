Fourchan =
  init: ->
    return if g.VIEW is 'catalog'

    board = g.BOARD.ID
    if board is 'g'
      $.globalEval '''
        window.addEventListener('prettyprint', function(e) {
          window.dispatchEvent(new CustomEvent('prettyprint:cb', {
            detail: prettyPrintOne(e.detail)
          }));
        }, false);
      '''
      Post.callbacks.push
        name: 'Parse /g/ code'
        cb:   @code
    if board is 'sci'
      # https://github.com/MayhemYDG/4chan-x/issues/645#issuecomment-13704562
      $.globalEval '''
        window.addEventListener('jsmath', function(e) {
          if (!jsMath) return;
          if (jsMath.loaded) {
            // process one post
            jsMath.ProcessBeforeShowing(e.target);
          } else if (jsMath.Autoload && jsMath.Autoload.checked) {
            // load jsMath and process whole document
            jsMath.Autoload.Script.Push('ProcessBeforeShowing', [null]);
            jsMath.Autoload.LoadJsMath();
          }
        }, false);
      '''
      Post.callbacks.push
        name: 'Parse /sci/ math'
        cb:   @math
      CatalogThread.callbacks.push
        name: 'Parse /sci/ math'
        cb:   @math
  code: ->
    return if @isClone
    apply = (e) ->
      pre.innerHTML = e.detail
      $.addClass pre, 'prettyprinted'
    $.on window, 'prettyprint:cb', apply
    for pre in $$ '.prettyprint:not(.prettyprinted)', @nodes.comment
      $.event 'prettyprint', pre.innerHTML, window
    $.off window, 'prettyprint:cb', apply
    return
  math: ->
    return if (@isClone and doc.contains @origin.nodes.root) or !$ '.math', @nodes.comment
    $.asap (=> doc.contains @nodes.comment), =>
      $.event 'jsmath', null, @nodes.comment
  parseThread: (threadID, offset, limit) ->
    # Fix /sci/
    # Fix /g/
    $.event '4chanParsingDone',
      threadId: threadID
      offset: offset
      limit: limit
