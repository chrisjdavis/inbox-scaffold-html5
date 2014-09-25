
define ["angular", "underscore"], (angular, _) ->
  angular.module("baobab.controller.thread", [])
  .controller('ThreadCtrl', ['$scope', '$namespaces', '$threads', '$modal', '$routeParams', '$location', '$scrollState',
    ($scope, $namespaces, $threads, $modal, $routeParams, $location, $scrollState) ->

      @thread = $threads.item($routeParams['id'])
      @messages = null
      @drafts = null
      $scope.replying = false

      @currentAttachment = null
      @currentAttachmentDataURL = null

      # internal methods

      threadReady = () =>
        @thread.messages().then((messages) =>
          @messages = messages.sort (a, b) -> a.date.getTime() - b.date.getTime()

          # scroll to the first unread message, or the last message
          # if the entire conversation is read.
          scrollTo = messages[-1]
          messages.every (message) ->
            if message.unread
              scrollTo = message
              return false
            return true

          if scrollTo != undefined
            $scrollState.scrollTo('msg-' + scrollTo.id)

            # mark the thread as read
            if (@thread.hasTag('unread'))
              @thread.removeTags(['unread']).then((response) ->
                messages.forEach (message) -> message.unread = false
              ,_handleAPIError)

        ,_handleAPIError)

        @.thread.drafts().then((drafts) =>
          @drafts = drafts.sort (a, b) -> a.date.getTime() - b.date.getTime()
        , _handleAPIError)


      $scope.$on "compose-replying", (event) =>
        $scope.replying = true


      $scope.$on "compose-cleared", (event) =>
        @draft = null
        $scope.replying = false


      # exposed methods

      @viewAttachment = (msg, id) =>
        @currentAttachmentLoading = true
        msg.attachment(id).download().then (blob) =>
          @currentAttachment = blob
          if (blob.type.indexOf('image/') != -1)
            fileReader = new FileReader()
            fileReader.onload = () =>
              @currentAttachmentDataURL = @result
              @currentAttachmentLoading = false
              $scope.$apply() unless $scope.$$phase
            fileReader.readAsDataURL(blob)
          else
            @currentAttachmentLoading = false
            @downloadCurrentAttachment()


      @hideAttachment = () =>
        @currentAttachmentDataURL = null
        @currentAttachment = null


      @downloadCurrentAttachment = () =>
        saveAs(@currentAttachment, @currentAttachment.fileName)


      @replyClicked = (replyAll) =>
        return if $scope.replying

        draft = @draft = @thread.reply()
        me = $namespaces.current().emailAddress
        lastMessage = @messages[-1]

        draft.to = _.union(lastMessage.from, lastMessage.to)
        draft.to = _.reject(draft.to, (p) -> p.email == me ) if to.length > 1
        draft.cc = _.reject(lastMessage.cc, (p) -> p.email == me ) if replyAll

        $scope.$broadcast("compose-set-draft", draft)


      @draftClicked = (msg) =>
        @draft = msg
        $scope.$broadcast("compose-set-draft", msg)


      @archiveClicked = () =>
        @thread.removeTags(['inbox']).then((response) =>
          $threads.itemArchived(@thread.id)
          $location.path('/inbox')
        , _handleAPIError)


      if (@thread)
        threadReady()
      else
        $namespaces.current().thread($routeParams['id']).then (thread) =>
          @thread = thread
          threadReady()
        , _handleAPIError

      @
  ])

