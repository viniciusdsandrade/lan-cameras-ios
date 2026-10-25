import SwiftUI
import CamerasCore
import CamerasSessao

/// A primeira tela, enquanto não há câmeras: o que o app faz, a busca (que começa sozinha ao abrir: é
/// isso que faz o iOS perguntar pela rede local), o que é preciso para dar certo e o endereço manual.
struct TelaDeCadastro: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @State private var endereco = ""
    @State private var jaProcurou = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.3, blue: 0.6), Color(red: 0.08, green: 0.12, blue: 0.3)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 88, height: 88)
                        .overlay(Image(systemName: "web.camera.fill").font(.system(size: 38)).foregroundStyle(.white.opacity(0.9)))
                        .accessibilityHidden(true)
                    Text("Câmeras de Casa").font(.largeTitle.weight(.bold))
                    Text("Veja e controle as câmeras da sua casa direto pelo Wi-Fi, sem a nuvem do fabricante.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
                Button {
                    modelo.procurarCameras()
                } label: {
                    if modelo.procurando {
                        HStack(spacing: 8) { ProgressView(); Text("Procurando…") }
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Procurar câmeras na rede", systemImage: "antenna.radiowaves.left.and.right").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(modelo.procurando)
                VStack(spacing: 10) {
                    passo("wifi", "Mesmo Wi-Fi", "O iPhone precisa estar no mesmo Wi-Fi que as câmeras.")
                    passo("key.fill", "Sem digitar senha", "O app pega com a própria câmera o que precisa para entrar.")
                    passo("network", "Rede local", "Se o iPhone perguntar se o app pode procurar aparelhos na rede local, toque em Permitir. Se tocou em Não Permitir, libere em Ajustes > Privacidade e Segurança > Rede Local.")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Não achou? Digite o endereço da câmera").font(.subheadline.weight(.semibold))
                    HStack {
                        TextField("Endereço IP da câmera", text: $endereco)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Adicionar") { modelo.adicionarPorEndereco(endereco) }
                            .buttonStyle(.bordered)
                            .disabled(endereco.trimmingCharacters(in: .whitespaces).isEmpty || modelo.procurando)
                    }
                }
                .cartao()
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tema.fundo.ignoresSafeArea())
        .navigationTitle("Câmeras de Casa")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !jaProcurou, !hospedandoTestesDeUnidade else { return }
            jaProcurou = true
            modelo.procurarCameras()
        }
    }

    private func passo(_ simbolo: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: simbolo).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.headline)
                Text(texto).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .cartao()
    }

    /// Hospedando testes de unidade, o app não sai procurando câmeras na rede (os testes de
    /// interface abrem o app como um processo à parte, sem esta variável, e procuram normalmente).
    private var hospedandoTestesDeUnidade: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// As câmeras guardadas: procurar de novo, adicionar por endereço, renomear e mudar a ordem.
struct TelaDeCameras: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @Environment(\.dismiss) private var fechar
    @State private var endereco = ""
    @State private var renomeando: CameraConfig?
    @State private var novoNome = ""

    var body: some View {
        List {
            Section {
                ForEach(modelo.cameras) { c in
                    Button {
                        novoNome = c.nome
                        renomeando = c
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.nome).foregroundStyle(.primary)
                                Text(c.modelo ?? "câmera").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint("Renomear")
                }
                .onMove { origem, destino in
                    var ids = modelo.cameras.map(\.id)
                    ids.move(fromOffsets: origem, toOffset: destino)
                    modelo.reordenar(ids)
                }
            } header: {
                Text("Guardadas neste iPhone")
            } footer: {
                Text("Toque para renomear; arraste (em Editar) para mudar a ordem da visão geral.")
            }

            Section("Procurar") {
                Button {
                    modelo.procurarCameras()
                } label: {
                    HStack {
                        Label(modelo.procurando ? "Procurando…" : "Procurar câmeras na rede", systemImage: "magnifyingglass")
                        if modelo.procurando { Spacer(); ProgressView() }
                    }
                }
                .disabled(modelo.procurando)
                HStack {
                    TextField("Endereço IP", text: $endereco)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Adicionar") { modelo.adicionarPorEndereco(endereco) }
                        .disabled(endereco.trimmingCharacters(in: .whitespaces).isEmpty || modelo.procurando)
                }
            }
        }
        .navigationTitle("Câmeras")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .confirmationAction) { Button("OK") { fechar() } }
        }
        .alert("Renomear a câmera", isPresented: Binding(get: { renomeando != nil }, set: { if !$0 { renomeando = nil } })) {
            TextField("Nome", text: $novoNome)
            Button("Salvar") { if let c = renomeando { modelo.renomear(c, para: novoNome) } }
            Button("Cancelar", role: .cancel) {}
        }
        .overlay(alignment: .bottom) { AvisoView() }
    }
}
