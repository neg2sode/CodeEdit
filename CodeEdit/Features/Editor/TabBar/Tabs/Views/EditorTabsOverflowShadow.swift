//
//  EditorTabsOverflowShadow.swift
//  CodeEdit
//
//  Created by Austin Condiff on 8/22/23.
//

import SwiftUI

struct EditorTabsOverflowShadow: View {
    var width: CGFloat
    var startPoint: UnitPoint
    var endPoint: UnitPoint

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.controlActiveState)
    private var activeState

    // Resolve the shadow opacity into an explicit Double. Passing the nested ternary
    // directly to `.opacity(...)` is ambiguous under the macOS 27 SDK / Swift 6.4
    // ("ambiguous use of 'opacity'"); this binding keeps identical behaviour.
    private var shadowOpacity: Double {
        if colorScheme == .dark {
            return activeState == .inactive ? 0.25882353 : 1
        }
        return activeState == .inactive ? 0.09803922 : 0.25882353
    }

    var body: some View {
        Rectangle()
            .frame(maxHeight: .infinity)
            .frame(width: width)
            .foregroundColor(.clear)
            .background(
                LinearGradient(
                    gradient: Gradient(
                        stops: [
                            Gradient.Stop(color: .black.opacity(0.75), location: 0),
                            Gradient.Stop(color: .black.opacity(0.25), location: 0.5),
                            Gradient.Stop(color: .black.opacity(0), location: 1)
                        ]
                    ),
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                .opacity(shadowOpacity)
            )
            .allowsHitTesting(false)
    }
}
