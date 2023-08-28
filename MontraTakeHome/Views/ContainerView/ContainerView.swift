//
//  ContainerView.swift
//  MontraTakeHome
//
//  Created by Seun Olalekan on 2023-08-25.
//

import SwiftUI

struct ContainerView: View {
    @StateObject private var containerViewModel : ContainerViewModel = .init()
    
    var body: some View {
        
        GeometryReader{ proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            HStack{
                Spacer()
                VStack(spacing:10){
                    Spacer()
                    //VideoPreview
                    if containerViewModel.isRecording, let previewLayer = containerViewModel.previewLayer {
                        VideoPreviewView(previewLayer:previewLayer)
                            .frame(width: width*0.8, height: height*0.7)
                    } else {
                        ZStack{
                            Rectangle().foregroundColor(.black)
                                .frame(width: width*0.8, height: height*0.7)
                            Text("Not Running")
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Camera Select Dropdown
                    MenuButton(label: Text(containerViewModel.selectedCameraTitle)) {
                        ForEach(containerViewModel.availableCameras, id: \.self) { camera in
                            Button(camera.localizedName) {
                                containerViewModel.setAVDevices(with: camera, mic: containerViewModel.selectedMic)
                            }
                        }
                        
                    }
                    .frame(width: width/2)
                    // Mic Select Dropdown
                    MenuButton(label: Text(containerViewModel.selectedMicTitle)) {
                        ForEach(containerViewModel.availableMics, id: \.self) { mic in
                            Button(mic.localizedName) {
                                containerViewModel.setAVDevices(with: containerViewModel.selectedCamera, mic: mic)
                            }
                        }
                        
                    }
                    .frame(width: width/2)
                    
                    Button {
                        // Toggle record
                        containerViewModel.isRecording.toggle()
                    } label: {
                        if containerViewModel.isRecording {
                            Label {
                                Text("Recording")
                            } icon: {
                                Image(systemName: "record.circle.fill")
                            }
                            .frame(width:width/5, height:30)
                            .foregroundColor(.red)
                        } else{
                            Label {
                                Text("Record")
                            } icon: {
                                Image(systemName: "record.circle")
                            }
                            .frame(width:width/5, height:30)
                            .foregroundColor(.black)
                            
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .onChange(of: containerViewModel.isRecording) { isRecording in
            if isRecording{
                containerViewModel.record()
            }else{
                containerViewModel.stopRecording()
            }
        }
        
        
    }
}

struct ContainerView_Previews: PreviewProvider {
    static var previews: some View {
        ContainerView()
    }
}
