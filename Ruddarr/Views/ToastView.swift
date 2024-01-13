//
//  ToastView.swift
//  Ruddarr
//
//  Created by apple on 13/01/24.
//

import Foundation
import SwiftUI

fileprivate
struct ToastView: View {
    
    var message: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text(message)
                        .font(.system(size: 13))
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 6)
                    .clipped()
                , alignment: .leading
            )
            .clipShape(.rect(cornerRadius: 8))
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .shadow(radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)
    }
}


fileprivate
struct ToastViewModifier: ViewModifier {
    @Binding var message: String?
    
    @State private var workItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            ZStack {
                mainToastView()
                    .offset(y: 8)
            }
            .animation(.spring(), value: message)
        }
        .onChange(of: message) { oldValue, newValue in
            setDismissal()
        }
    }
    
    @ViewBuilder
    func mainToastView() -> some View {
        if let message = message {
            VStack {
                ToastView(message: message)
                Spacer()
            }
            .transition(.move(edge: .top))
        }
    }
    
    func setDismissal() {
        guard let _ = message else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        workItem?.cancel()
        
        let task = DispatchWorkItem {
            withAnimation {
                message = nil
            }
            
            workItem?.cancel()
            workItem = nil
        }
        
        workItem = task
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
    }
}


extension View {
    func errorToast(with message: Binding<String?>) -> some View {
        self.modifier(ToastViewModifier(message: message))
    }
}
