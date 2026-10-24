import SwiftUI
import CamerasCore
import CamerasSessao

/// Para onde a pilha de navegação vai, por cima da visão geral: uma câmera ou as gravações.
enum Destino: Hashable {
    case camera(String)
    case gravacoes

    static func caminho(_ selecao: ModeloDoApp.Selecao) -> [Destino] {
        switch selecao {
        case .geral: return []
        case .camera(let id): return [.camera(id)]
        case .gravacoes: return [.gravacoes]
        }
    }

    static func selecao(_ caminho: [Destino]) -> ModeloDoApp.Selecao {
        switch caminho.last {
        case .camera(let id)?: return .camera(id)
        case .gravacoes?: return .gravacoes
        case nil: return .geral
        }
    }
}

/// A raiz do app: o cadastro enquanto não há câmeras; depois, a visão geral com a câmera ou as
/// gravações por cima (a pilha de navegação segue a seleção do modelo, que decide quais sessões
/// ficam abertas).
struct TelaPrincipal: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @State private var mostrandoCameras = false
    @State private var mostrandoAjuda = false

    var body: some View {
        Group {
            if modelo.cameras.isEmpty {
                NavigationStack { TelaDeCadastro() }
            } else {
                NavigationStack(path: caminho) {
                    VisaoGeral(mostrandoCameras: $mostrandoCameras, mostrandoAjuda: $mostrandoAjuda)
                        .navigationDestination(for: Destino.self) { destino in
                            switch destino {
                            case .camera(let id): VisaoDaCamera(idDaCamera: id)
                            case .gravacoes: TelaDeGravacoes(cartoes: modelo.cartoes)
                            }
                        }
                }
            }
        }
        .overlay(alignment: .bottom) { AvisoView() }
        .animation(.easeInOut(duration: 0.2), value: modelo.aviso)
        .sheet(isPresented: $mostrandoCameras) { NavigationStack { TelaDeCameras() } }
        .sheet(isPresented: $mostrandoAjuda) { NavigationStack { AjudaView() } }
        .task {
            // com a conta Apple gratuita o app para de abrir em 7 dias: avisa antes
            if Assinatura.deveAvisar(), let texto = Assinatura.descricao() { modelo.avisar(texto, .erro) }
        }
    }

    private var caminho: Binding<[Destino]> {
        Binding(get: { Destino.caminho(modelo.selecao) }, set: { modelo.selecionar(Destino.selecao($0)) })
    }
}
