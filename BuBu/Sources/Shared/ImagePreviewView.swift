//
//  ImagePreview.swift
//  BuBu
//
//  Created by Gwyneth on 2026/4/14.
//


import SwiftUI

struct ImagePreviewView: View {
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Angle = .degrees(0)
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    private let imageUrl: URL?
    
    init(imageUrl: URL?) {
        self.imageUrl = imageUrl
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                if let uiImage = LocalImageLoader.loadUIImage(from: imageUrl) {
                    // 替换为你的图片名称
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .rotationEffect(rotation)
                        .offset(offset)
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    // 双击重置
                                    withAnimation {
                                        scale = 1.0
                                        rotation = .degrees(0)
                                        offset = .zero
                                    }
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value.magnitude
                                }
                                .onEnded { value in
                                    scale = value.magnitude
                                }
                        )
                        .gesture(
                            RotationGesture()
                                .onChanged { rotation in
                                    self.rotation = rotation
                                }
                                .onEnded { rotation in
                                    self.rotation = rotation
                                }
                        )
//                        .gesture(
//                            DragGesture()
//                                .onChanged { value in
//                                    guard !isDragging else { return }
//                                    offset = value.translation
//                                }
//                                .onEnded { value in
//                                    guard !isDragging else { return }
//                                    offset = value.predictedEndTranslation
//                                }
//                        )
                }
                
                Spacer()
                
                // 控制按钮
                HStack {
                    Button(action: {
                        withAnimation {
                            scale = max(0.5, scale - 0.2)
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(AppTheme.Colors.primaryColor)
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        withAnimation {
                            scale = 1.0
                            rotation = .degrees(0)
                            offset = .zero
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(AppTheme.Colors.primaryColor)
                            .clipShape(Circle())
                        
                    }
                    
                    Button(action: {
                        withAnimation {
                            scale = min(3.0, scale + 0.2)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(AppTheme.Colors.primaryColor)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 30)
            }.frame(width: geometry.size.width,height: geometry.size.height)
        }
    }
}
