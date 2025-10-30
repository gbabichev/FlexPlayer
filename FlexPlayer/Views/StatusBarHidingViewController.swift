//
//  StatusBarHidingViewController.swift
//  FlexPlayer
//

import AVKit

class StatusBarHidingViewController: AVPlayerViewController {
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}
