Live content the server reads at connect time. Nothing here is required — with
this folder empty the screen shows the lists from config.js and the locale pack
exactly as before.

  news.json            server news / patch notes for the News tab
  tips.json            the tip list under the welcome line
  rules_accepted.json  written by the resource: who accepted which rules
                       version. Do not edit it by hand; clear it with
                       `lrl_rules_reset all` from the server console.

Both content files are re-read while the server runs — save the file and the
next player to connect sees it. Force it immediately with `lrl_reload`.

news.json — a bare array, or an object with a "news" key:

  [
    {
      "tag": "Update",
      "date": "2026-07-24",
      "title": "Winter update",
      "body": [
        "Two new legal jobs at the docks.",
        "Vehicle handling pass on every sports car."
      ]
    }
  ]

Every field is optional except that an entry needs a title or a body. "body"
may also be a single string with newlines. At most 12 entries are sent.

tips.json — a bare array of strings, or an object with a "tips" key:

  [
    "Press F1 to open your phone.",
    "Withdraw your paycheck at any ATM."
  ]

At most 30 tips are sent.

Two other sources beat these files, in this order:

  1. Another resource pushing content at runtime:
       exports.lastresort_loading:SetNews({ ... })
       exports.lastresort_loading:SetTips({ ... })
  2. A URL polled over HTTP — the true no-touch route, for a web panel or a
     Discord bot that already publishes JSON:
       setr lrl:newsUrl "https://example.com/news.json"
       setr lrl:tipsUrl "https://example.com/tips.json"
       setr lrl:contentRefreshMinutes 5    # 0 to fetch once at startup only

  One endpoint can serve both: a document with "news" and "tips" keys set as
  lrl:newsUrl fills both lists.
