import SwiftUI
import CamerasCore
import CamerasSessao

@main
struct CamerasDeCasaApp: App {
    @StateObject private var modelo = ModeloDoApp()

    var body: some Scene {
        WindowGroup {
            TelaPrincipal()
                .environmentObject(modelo)
                .preferredColorScheme(.dark)           // vídeo em fundo escuro, como num visor
                .tint(Color("AccentColor"))
        }
    }
}
