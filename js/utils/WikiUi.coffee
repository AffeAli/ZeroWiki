class WikiUi

  #
  # Set up basic document elements.
  #

  constructor: ->
    @historyTools   = document.getElementById("content-history-tools")
    @viewTools      = document.getElementById("content-view-tools")
    @editTools      = document.getElementById("content-edit-tools")
    @contentPanel   = document.getElementById("messages")
    @contentEditor  = document.getElementById("editor")
    @contentHistory = document.getElementById("history")
    @markedOptions  = {"gfm": true, "breaks": true, "sanitize": true}

  #
  # Hide all tools controls.
  #

  hideTools: ->
    @historyTools.style.display = "none"
    @viewTools.style.display    = "none"
    @editTools.style.display    = "none"

  #
  # Show history tools.
  #

  showHistoryTools: ->
    @historyTools.style.display = "block"

  #
  # Show view tools.
  #

  showViewTools: ->
    @viewTools.style.display = "block"

  #
  # Show edit tools.
  #

  showEditTools: ->
    @editTools.style.display = "block"

  #
  # Hide all content panels.
  #

  hidePanels: ->
    @contentPanel.style.display   = "none"
    @contentEditor.style.display  = "none"
    @contentHistory.style.display = "none"

  #
  # Show the main content panel.
  #

  showContent: (rev=null)->
    @hideTools()
    @showViewTools()
    @hidePanels()
    if rev isnt null
      document.getElementById('revision').style.display  = "block"
      document.getElementById('edit_page').style.display = "none"

    @contentPanel.style.display = "block"

  #
  # Show the editor panel.
  #

  showEdit: ->
    @hideTools()
    @showEditTools()
    @hidePanels()
    @contentEditor.style.display = "block"
    @contentEditor.focus()

  #
  # Show new page message
  #

  showNewPageMessage: ->
    @hideTools()
    @hidePanels()
    body  = "<div class=\"new-page-message\">"
    body += "<p class=\"muted\">This page doesn't exist yet.</p>"
    body += "<p><a href=\"#\" class=\"pure-button\" onclick=\"return Page.pageEdit()\">Create this page</a></p>"
    body += "</div>"
    @contentPanel.innerHTML = body
    @contentPanel.style.display = "block"

  #
  # Show the history panel.
  #

  showHistory: (messages) ->
    @hideTools()
    @showHistoryTools()
    @hidePanels()
    @contentHistory.style.display = "block"
    history_list = document.getElementById("history_list")
    body = ""
    i = 0
    for message in messages
      parsedDate = Time.since(message.date_added / 1000)
      body += "<li>Edited by #{message.cert_user_id} <span class=\"muted\">#{parsedDate}</span>"
      if i + 1 < messages.length
        body += "<a href=\"?Page:#{message.slug}&Rev:#{message.id}&Diff:#{messages[i + 1].id}\" class=\"pure-button button-success\" style=\"margin-left:10px;\">View Diff</a>"
      body += "<a href=\"?Page:#{message.slug}&Rev:#{message.id}\" class=\"pure-button button-success\">"
      body += "View</a></li>"
      i++
    history_list = document.getElementById("history_list")
    history_list.innerHTML = body

  #
  # Show the diff between versions.
  #

  showPageDiff: (from, to) ->
    query = "SELECT * FROM pages WHERE id = \"#{to}\""
    window.Page.cmd "dbQuery", [query], (pages) =>
      query = "SELECT * FROM pages, keyvalue LEFT JOIN json using (json_id) WHERE id = \"#{from}\""
      window.Page.cmd "dbQuery", [query], (pages2) =>
        base = difflib.stringAsLines(pages[0].body) # Generate diff
        newtxt = difflib.stringAsLines(pages2[0].body)
        sm = new difflib.SequenceMatcher(base, newtxt)

        diffoutputdiv = document.getElementById("messages")
        diffoutputdiv.innerHTML = ""
        diffoutputdiv.appendChild(diffview.buildView({ # Show diff
        baseTextLines: base,
        newTextLines: newtxt,
        opcodes: sm.get_opcodes(),
        baseTextName: from,
        newTextName: to,
        contextSize: 4,
        viewType: 0
        }));
        # Add additional informations
        query = """
          SELECT pages.*, keyvalue.value AS cert_user_id FROM pages
                LEFT JOIN json AS data_json USING (json_id)
                LEFT JOIN json AS content_json ON (
                    data_json.directory = content_json.directory AND content_json.file_name = 'content.json'
                )
                LEFT JOIN keyvalue ON (keyvalue.key = 'cert_user_id' AND keyvalue.json_id = content_json.json_id)
                WHERE pages.id = '#{from}'
        """
        window.Page.cmd "dbQuery", [query], (res) => 
          fromHTML = "<a href=\"?Page:#{window.Page.getSlug()}&Rev:#{from}\">#{from}</a><br>by #{res[0].cert_user_id} (#{Time.since(res[0].date_added / 1000)})"
          diffoutputdiv.firstChild.firstChild.getElementsByClassName("texttitle")[0].innerHTML = fromHTML
        query = query.replace("#{from}", "#{to}")
        window.Page.cmd "dbQuery", [query], (res) =>
          toHTML = "<a href=\"?Page:#{window.Page.getSlug()}&Rev:#{to}\">#{to}</a><br>by #{res[0].cert_user_id} (#{Time.since(res[0].date_added / 1000)})"
          diffoutputdiv.firstChild.firstChild.getElementsByClassName("texttitle")[1].innerHTML = toHTML
        @showContent()
      
  #
  # Load content into the dom. The editor loads the raw content from
  # the database and the content panel gets the HTML version.
  #

  loadContent: (originalContent, HTMLContent, rev=null) ->
    @contentEditor.innerHTML = originalContent
    @contentPanel.innerHTML  = HTMLContent
    for link in @contentPanel.querySelectorAll('a:not(.internal)')
      link.className += ' external'
      if link.href.indexOf(location.origin) == 0
        link.className += ' zeronet'
      else
        link.className += ' clearnet'
    @showContent(rev)

  #
  # Load the index page with all page links and orphaned pages.
  #

  showIndexPage: (links, orphaned) ->
    @hideTools()
    @hidePanels()
    @contentPanel.style.display = "block"

    body = ""
    linksBody = ""
    for link in links
      linksBody += "<li>#{link}</li>"

    if linksBody != ""
      body = "<h1>Linked Pages</h1><ul>#{linksBody}</ul>"

    if orphaned.length > 0
      body += "<h1>Orphaned pages</h1><ul>"
      for link in orphaned
        body += "<li>#{link}</li>"
      body += "</ul>"

    if body == ""
      body = "<p class=\"muted\">There are no pages yet.</p>"

    @contentPanel.innerHTML = body

  #
  # Show the login message.
  #

  loggedInMessage: (cert) ->
    if cert
      document.getElementById("select_user").innerHTML = "You are logged in as #{cert}"
    else
      document.getElementById("select_user").innerHTML = "Login"

  #
  # Update user quota message
  #

  setUserQuota: (current=null, max=null) ->
    quotaElement = document.getElementById("user_quota")
    if current isnt null and max isnt null
      quotaElement .innerHTML = "(#{(current / 1024).toFixed(1)}kb/#{(max / 1024).toFixed(1)}kb)"
    else
      quotaElement.innerHTML = ""

window.WikiUi = new WikiUi
