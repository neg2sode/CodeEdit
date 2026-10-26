//
//  AboutFooterView.swift
//  CodeEdit
//
//  Created by Giorgi Tchelidze on 08.06.25.
//

import SwiftUI
import AboutWindow

struct AboutFooterView: View {
    /// Set only for nightly/pre-release builds (see Configs/Pre.xcconfig). Official
    /// builds leave it empty and show just the licence and copyright.
    private var identity: String? { Bundle.buildIdentity }
    private var identityURL: URL? { Bundle.buildIdentityURL }

    private let licenceURL = URL(string: "https://github.com/CodeEditApp/CodeEdit/blob/main/LICENSE.md")!

    var body: some View {
        FooterView(
            primaryView: {
                HStack(spacing: 6) {
                    if let identity {
                        // Make clear this is not an official CodeEdit release.
                        if let identityURL {
                            Link(identity, destination: identityURL).underline()
                        } else {
                            Text(identity)
                        }
                        Text("·")
                    }
                    Link(destination: licenceURL) {
                        Text("MIT License")
                            .underline()
                    }
                }
            },
            secondaryView: {
                Text(Bundle.copyrightString ?? "")
            }
        )
    }
}
