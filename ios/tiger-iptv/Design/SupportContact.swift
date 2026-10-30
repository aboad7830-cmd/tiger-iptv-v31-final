//
//  SupportContact.swift
//  TigerIPTV
//
//  Central place for the official support contact details, plus a reusable
//  card that surfaces them in Settings (WhatsApp + phone number + copy).
//

import SwiftUI
import UIKit

// MARK: - Contact details

enum TigerSupport {
    /// Direct WhatsApp chat link (short link, works on iOS and the web).
    static let whatsappURL = URL(string: "https://wa.me/919154347808")!
    /// Human readable number, kept in sync with the WhatsApp account above.
    static let phoneNumber = "+91 91 5434 780 8"
    /// Dialable form (no spaces) used for `tel:` links.
    static let phoneDial = "+919154347808"
    static let phoneURL = URL(string: "tel://\(phoneDial)")!
    static let emailURL = URL(string: "mailto:support@tiger-iptv.com")!
}

// MARK: - Card

/// A tidy, instructional support card. Shows the WhatsApp button and the
/// phone number with a one-tap copy affordance.
struct TigerSupportCard: View {
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(TigerTheme.orange.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "headphones")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TigerTheme.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("support.title"))
                        .font(.subheadline.weight(.bold))
                    Text(L("support.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Link(destination: TigerSupport.whatsappURL) {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 15, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("support.whatsapp"))
                            .font(.subheadline.weight(.semibold))
                        Text(TigerSupport.phoneNumber)
                            .font(.caption2)
                            .opacity(0.85)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: TigerTheme.Radius.md, style: .continuous)
                        .fill(TigerTheme.orangeGradient)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Link(destination: TigerSupport.phoneURL) {
                    HStack(spacing: 7) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(TigerSupport.phoneNumber)
                            .font(.footnote.weight(.semibold))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .foregroundStyle(TigerTheme.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(TigerTheme.orange.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(TigerTheme.orange.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    Pasteboard.copy(TigerSupport.phoneDial)
                    TigerHaptics.tap(1)
                    withAnimation(.easeOut(duration: 0.2)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeOut(duration: 0.2)) { copied = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .bold))
                        Text(copied ? L("support.copied") : L("support.copy"))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(copied ? Color.green : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: TigerTheme.Radius.lg, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TigerTheme.Radius.lg, style: .continuous)
                .strokeBorder(TigerTheme.orange.opacity(0.18), lineWidth: 1)
        )
    }
}

/// Compact single-row variant used inside `List` sections.
struct TigerSupportRow: View {
    var body: some View {
        Link(destination: TigerSupport.whatsappURL) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(TigerTheme.orangeGradient)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("settings.about.github.title"))
                    Text(TigerSupport.phoneNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
