//
//  InitProgress.swift
//  Data SDI
//
//  Created by Bismillah on 17/11/24.
//

import Cocoa

class InitProgress: NSViewController {
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    @IBOutlet weak var indicator: ITProgressIndicator!
    override func loadView() {
        super.loadView()
        indicator.wantsLayer = true
        if NSApp.effectiveAppearance.name == NSAppearance.Name.darkAqua || NSApp.effectiveAppearance.name == NSAppearance.Name.vibrantDark {
            indicator.color = .white
        } else if NSApp.effectiveAppearance.name == NSAppearance.Name.vibrantLight || NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            indicator.color = .black
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 8
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .popover
        visualEffect.state = .followsWindowActiveState
        // Do view setup here.
    }
}
