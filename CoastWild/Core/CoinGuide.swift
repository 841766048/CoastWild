import Foundation

/// Editorial material sold by the native local wallet, separate from free lessons.
public enum CoinGuide {
  public static let id = "coastal-camping"
  public static let title = "Coastal Camping"
  public static let price = 30
  public struct Chapter {
    public let title: String
    public let paragraphs: [String]
    public let tipTitle: String
    public let tip: String
  }
  public static let chapters: [Chapter] = [
    Chapter(title: "Choose your campsite", paragraphs: [
      "Choose an established campsite on durable ground. Check local camping rules before you arrive.",
      "Look for shelter from the wind and keep clear of cliff edges. Keep your tent and gear above the high-tide line."
    ], tipTitle: "Before you settle in", tip: "Check tide times and the overnight forecast."),
    Chapter(title: "Set up for coastal wind", paragraphs: [
      "Choose a sheltered, permitted site away from unstable trees and exposed headlands. Avoid low spots where rainwater can collect.",
      "Pitch your tent as its maker recommends, with the smallest face toward the wind. Secure every guyline with anchors suited to the ground; loose sand may need longer stakes.",
      "Keep gear inside and check tension as the fabric settles. If wind exceeds your equipment or experience, pack up early and use a sheltered alternative."
    ], tipTitle: "Check before dark", tip: "Keep your headlamp, shoes and exit route easy to reach."),
    Chapter(title: "Cook and store safely", paragraphs: [
      "Use a stable cooking area outdoors, well clear of tents and dry vegetation. Never use a stove or barbecue inside a tent, even with the door open.",
      "Follow local fire restrictions. Keep water nearby, let your stove cool fully before packing, and never leave cooking unattended.",
      "Store food and scented items according to local wildlife guidance. Seal waste and take it with you; do not leave scraps for animals."
    ], tipTitle: "Plan your water", tip: "Bring sufficient drinking water. Do not assume a coastal stream is safe to drink."),
    Chapter(title: "Leave no trace", paragraphs: [
      "Use established paths and campsites. Give nesting birds and other wildlife space, and keep noise low around other campers.",
      "Pack out all rubbish, including food scraps and small pieces of cord. Use designated toilets and follow local guidance for waste where facilities are absent.",
      "Before leaving, walk the site once more. Remove every peg and restore any moved natural material without disturbing vegetation."
    ], tipTitle: "One final look", tip: "Leave the campsite ready for the next person, not marked by your visit.")
  ]
}
