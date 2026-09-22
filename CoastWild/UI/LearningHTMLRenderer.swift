import UIKit

enum LearningHTMLRenderer {
  static func render(lesson: CoastLesson, chinese: Bool) throws -> String {
    guard let detail = lesson.webDetail else { throw LearningRequestError.notFound }
    func text(_ value: [String: String]?) -> String {
      escape(value?[chinese ? "zh-Hans" : "en"] ?? value?["en"] ?? "")
    }
    let hero = dataURI(named: lesson.image)
    let highlights = detail.highlights.enumerated().map { index, value in
      "<li><b>\(index + 1)</b><span>\(text(value))</span></li>"
    }.joined()
    let blocks = detail.blocks.map { block in
      let heading = block.title.map { "<h2>\(text($0))</h2>" } ?? ""
      let body = block.body.map { "<p>\(text($0))</p>" } ?? ""
      switch block.type {
      case "image":
        return "<section>\(heading)\(body)<img class='article-image' src='\(dataURI(named: block.image ?? lesson.image))'></section>"
      case "callout": return "<aside class='callout'><span>!</span><div>\(heading)\(body)</div></aside>"
      case "checklist", "steps":
        let items = (block.items ?? []).map { "<li><i>✓</i>\(text($0))</li>" }.joined()
        return "<section>\(heading)<ul class='checklist'>\(items)</ul></section>"
      case "quote": return "<blockquote>“\(text(block.body))”</blockquote>"
      case "diagram":
        return "<section>\(heading)\(body)<div class='diagram'><img src='\(dataURI(named: block.image ?? lesson.image))'></div></section>"
      default: return "<section>\(heading)\(body)</section>"
      }
    }.joined()
    let sources = lesson.sourceLinks.map {
      "<a class='source' href='\(escape($0.url))'><span>↗</span><div><b>\(text($0.title))</b><small>\(escape($0.organization))</small></div></a>"
    }.joined()
    let nextLink = detail.nextLessonID.map { "coastwild://lesson/\(escape($0))" } ?? "#"
    return """
    <!doctype html><html lang='\(chinese ? "zh-Hans" : "en")'><head>
    <meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>
    <style>
    :root{--teal:#075E73;--ink:#102F36;--muted:#60757D;--sand:#F7F2E6;--line:#D9E4E7}*{box-sizing:border-box}
    body{margin:0;padding:18px 16px 48px;background:#fff;color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;font-size:17px;line-height:1.65}
    .eyebrow{color:var(--muted);font-size:13px;font-weight:600}h1{font-size:32px;line-height:1.18;margin:8px 0 10px;letter-spacing:-.5px}h2{font-size:24px;line-height:1.25;margin:28px 0 8px}p{margin:0 0 14px}.summary{color:var(--muted);font-size:16px}.hero,.article-image,.diagram img{display:block;width:100%;border-radius:16px;margin:18px 0;object-fit:cover}.hero{height:236px}.article-image{max-height:240px}.byline{display:flex;align-items:center;gap:10px;margin:10px 0 18px}.avatar{width:42px;height:42px;border-radius:50%;background:var(--teal);color:#fff;display:grid;place-items:center;font-weight:700}.byline small{display:block;color:var(--muted)}
    .highlights{background:var(--sand);border-radius:16px;padding:18px;margin:20px 0}.highlights h2{margin:0 0 12px}.highlights ol{padding:0;margin:0;list-style:none;display:grid;gap:12px}.highlights li{display:flex;gap:12px}.highlights b{color:var(--teal)}
    .callout{display:flex;gap:12px;border:1.5px solid #52B8CE;background:#EFFBFD;border-radius:14px;padding:15px;margin:22px 0}.callout>span{width:26px;height:26px;border:2px solid var(--teal);border-radius:50%;display:grid;place-items:center;font-weight:800}.callout h2{font-size:18px;margin:0 0 3px}.callout p{font-size:15px;margin:0}.checklist{padding:0;list-style:none;display:grid;gap:10px}.checklist li{border:1px solid var(--line);border-radius:12px;padding:13px 14px}.checklist i{color:var(--teal);font-style:normal;margin-right:10px}blockquote{margin:24px 0;padding:20px;background:var(--sand);border-radius:16px;color:#9B671D;font-weight:650}.sources{border:1px solid var(--line);border-radius:16px;padding:14px;margin-top:26px}.sources h2{font-size:20px;margin:0 0 8px}.source{display:flex;gap:10px;padding:11px 0;color:var(--ink);text-decoration:none;border-top:1px solid var(--line)}.source small{display:block;color:var(--muted)}.cta{margin-top:24px;padding:20px;background:var(--teal);color:#fff;border-radius:16px}.cta h2{margin:0;color:#fff}.cta a{display:block;margin-top:12px;border:0;border-radius:22px;background:#fff;color:var(--teal);font-size:16px;font-weight:700;padding:12px 18px;text-align:center;text-decoration:none}
    </style></head><body>
    <div class='eyebrow'>\(chinese ? "新手指南" : "BEGINNER GUIDE") · \(lesson.readingMinutes) \(chinese ? "分钟阅读" : "MIN READ")</div>
    <h1>\(text(lesson.title))</h1><p class='summary'>\(text(lesson.summary))</p>
    <img class='hero' src='\(hero)'><div class='byline'><div class='avatar'>CW</div><div><b>\(text(detail.author))</b><small>\(chinese ? "更新于" : "Updated") \(escape(detail.updatedAt))</small></div></div>
    <div class='highlights'><h2>\(chinese ? "先记住这三件事" : "Remember these three things")</h2><ol>\(highlights)</ol></div>
    \(blocks)
    <div class='sources'><h2>\(chinese ? "资料与安全说明" : "Sources & safety")</h2>\(sources)<p class='summary'>\(chinese ? "本指南为入门参考，不能替代现场专业指导与安全判断。" : "This introduction cannot replace qualified on-site instruction or safety judgment.")</p></div>
    <div class='cta'><h2>\(chinese ? "准备好继续了吗？" : "Ready to continue?")</h2><p>\(chinese ? "继续学习下一篇内容" : "Continue to the next lesson")</p><a href='\(nextLink)'>\(chinese ? "继续学习" : "Continue learning") →</a></div>
    </body></html>
    """
  }

  static func escape(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private static func dataURI(named name: String) -> String {
    guard let image = UIImage(named: name), let data = image.jpegData(compressionQuality: 0.86) else { return "" }
    return "data:image/jpeg;base64," + data.base64EncodedString()
  }
}
