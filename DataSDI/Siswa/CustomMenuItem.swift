//
//  CustomMenuItem.swift
//  Data SDI
//
//  Created by Bismillah on 23/12/24.
//

import Cocoa

class TagControl: NSControl {
  var isSelected: Bool = false
  let color: NSColor

  var mouseInside: Bool = false {
    didSet {
      needsDisplay = true
    }
  }

  init (_ color: NSColor, frame: NSRect) {
    self.color = color
    super.init(frame: frame)

    if trackingAreas.isEmpty {
      let trackingArea = NSTrackingArea(
        rect: frame,
        options: [
          .activeInKeyWindow,
          .mouseEnteredAndExited,
          .inVisibleRect],
        owner: self,
        userInfo: nil)
      addTrackingArea(trackingArea)
    }
  }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
  override func mouseEntered(with event: NSEvent) {
    mouseInside = true
  }

  override func mouseExited(with event: NSEvent) {
    mouseInside = false
  }

  override func mouseDown(with event: NSEvent) {
    if let action = action {
      NSApp.sendAction(action, to: target, from: self)
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    color.set()

    let circleRect: NSRect

    if mouseInside {
      circleRect = dirtyRect
    } else {
      circleRect = NSInsetRect(dirtyRect, 3, 3)
    }

    let circle = NSBezierPath(ovalIn: circleRect)
    circle.fill()

    let strokeColor = color.shadow(withLevel: 0.2)
    let insetRect = NSInsetRect(circleRect, 1.0, 1.0)
    let insetCircle = NSBezierPath(ovalIn: insetRect)

    strokeColor?.set()
    insetCircle.fill()

    // Draw remove icon and return early
    if mouseInside && isSelected {
      let iconRect = NSInsetRect(dirtyRect, 6, 6)
      let iconPath = removePath(iconRect)
      NSColor.white.setFill()
      iconPath.fill()
      return
    }

    // Else draw the add icon
    if mouseInside {
      let iconRect = NSInsetRect(dirtyRect, 6, 6)
      let iconPath = addPath(iconRect)
      NSColor.white.setFill()
      iconPath.fill()
    }

    // Draw the tick icon
    if isSelected {
      let iconRect = NSInsetRect(dirtyRect, 6, 6)
      let iconPath = tickPath(iconRect)
      NSColor.white.setFill()
      iconPath.fill()
    }
  }
    func addPath(_ rect: NSRect) -> NSBezierPath {
      let minX = NSMinX(rect)
      let minY = NSMinY(rect)

      let path = NSBezierPath()
      path.move(to: NSPoint(x: minX + 0.5, y: minY + 3.25))
      path.line(to: NSPoint(x: minX + 3.25, y: minY + 3.25))
      path.line(to: NSPoint(x: minX + 3.25, y: minY + 0.5))
      path.line(to: NSPoint(x: minX + 4.75, y: minY + 0.5))
      path.line(to: NSPoint(x: minX + 4.75, y: minY + 3.25))
      path.line(to: NSPoint(x: minX + 7.5, y: minY + 3.25))
      path.line(to: NSPoint(x: minX + 7.5, y: minY + 4.75))
      path.line(to: NSPoint(x: minX + 4.75, y: minY + 4.75))
      path.line(to: NSPoint(x: minX + 4.75, y: minY + 7.5))
      path.line(to: NSPoint(x: minX + 3.25, y: minY + 7.5))
      path.line(to: NSPoint(x: minX + 3.25, y: minY + 4.75))
      path.line(to: NSPoint(x: minX + 0.5, y: minY + 4.75))
      path.close()
      return path
    }

    func removePath(_ rect: NSRect) -> NSBezierPath {
      let minX = NSMinX(rect)
      let minY = NSMinY(rect)

      let path = NSBezierPath()
      path.move(to: NSPoint(x: minX, y: minY + 1))
      path.line(to: NSPoint(x: minX + 1, y: minY))
      path.line(to: NSPoint(x: minX + 4, y: minY + 3))
      path.line(to: NSPoint(x: minX + 7, y: minY))
      path.line(to: NSPoint(x: minX + 8, y: minY + 1))
      path.line(to: NSPoint(x: minX + 5, y: minY + 4))
      path.line(to: NSPoint(x: minX + 8, y: minY + 7))
      path.line(to: NSPoint(x: minX + 7, y: minY + 8))
      path.line(to: NSPoint(x: minX + 4, y: minY + 5))
      path.line(to: NSPoint(x: minX + 1, y: minY + 8))
      path.line(to: NSPoint(x: minX, y: minY + 7))
      path.line(to: NSPoint(x: minX + 3, y: minY + 4))
      path.close()
      return path
    }

    func tickPath(_ rect: NSRect) -> NSBezierPath {
      let minX = NSMinX(rect)
      let minY = NSMinY(rect)

      let path = NSBezierPath()
      path.move(to: NSPoint(x: minX + 2, y: minY))
      path.line(to: NSPoint(x: minX + 8, y: minY + 7))
      path.line(to: NSPoint(x: minX + 7, y: minY + 8))
      path.line(to: NSPoint(x: minX + 2.5, y: minY + 2.5))
      path.line(to: NSPoint(x: minX + 1.5, y: minY + 4.5))
      path.line(to: NSPoint(x: minX, y: minY + 4))
      path.close()
      return path
    }

}

class TagViewController: NSViewController {
  override func loadView() {
    view = NSView()
  }

  @objc func tagClicked(_ sender: AnyObject?) {
    guard let tag = sender as? TagControl else { return }
    
    tag.isSelected.toggle()
  }

  override func viewDidLoad() {
    let redTag = TagControl(.red, frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    let blueTag = TagControl(.blue, frame: NSRect(x: 24, y: 0, width: 20, height: 20))
    let greenTag = TagControl(.green, frame: NSRect(x: 48, y: 0, width: 20, height: 20))
    let yellowTag = TagControl(.yellow, frame: NSRect(x: 72, y: 0, width: 20, height: 20))
    let orangeTag = TagControl(.orange, frame: NSRect(x: 96, y: 0, width: 20, height: 20))
    let grayTag = TagControl(.gray, frame: NSRect(x: 120, y: 0, width: 20, height: 20))

    redTag.tag = 0
    redTag.target = self
    redTag.action = #selector(tagClicked(_:))

    blueTag.tag = 1
    blueTag.target = self
    blueTag.action = #selector(tagClicked(_:))

    greenTag.tag = 2
    greenTag.target = self
    greenTag.action = #selector(tagClicked(_:))

    yellowTag.tag = 3
    yellowTag.target = self
    yellowTag.action = #selector(tagClicked(_:))

    orangeTag.tag = 4
    orangeTag.target = self
    orangeTag.action = #selector(tagClicked(_:))

    grayTag.tag = 5
    grayTag.target = self
    grayTag.action = #selector(tagClicked(_:))

    view.addSubview(redTag)
    view.addSubview(blueTag)
    view.addSubview(greenTag)
    view.addSubview(yellowTag)
    view.addSubview(orangeTag)
    view.addSubview(grayTag)
  }
}
