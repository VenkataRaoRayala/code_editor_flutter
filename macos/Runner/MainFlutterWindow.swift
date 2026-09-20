import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(width: 1280, height: 800)

    let desiredContentSize = NSSize(width: 1440, height: 920)
    if self.contentLayoutRect.size.width < desiredContentSize.width ||
        self.contentLayoutRect.size.height < desiredContentSize.height {
      self.setContentSize(desiredContentSize)
    } else {
      self.setFrame(windowFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
