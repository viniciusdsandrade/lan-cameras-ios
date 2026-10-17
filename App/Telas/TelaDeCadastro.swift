import SwiftUI
import CamerasCore
import CamerasSessao

/// A primeira tela, enquanto não há câmeras: procura sozinha ao abrir (é isso que faz o iOS
/// perguntar pela rede local) e oferece o endereço manual.
struct TelaDeCadastro: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @State private var endereco = ""
    @State private var jaProcurou = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
                Text("Nenhuma câmera cadastrada").font(.title2.weight(.semibold))
                Text("O app procura as câmeras no Wi-Fi da sua casa e pega delas mesmas o que precisa para entrar: você não digita usuário nem senha. O iPhone precisa estar no mesmo Wi-Fi que elas.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    modelo.procurarCameras()
                } label: {
                    if modelo.procurando {
                        HStack(spacing: 8) { ProgressView(); Text("Procurando…") }
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Procurar câmeras na rede", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(modelo.procurando)

                Text("Se o iPhone perguntar se o app pode procurar aparelhos na rede local, toque em Permitir. Se tocou em Não Permitir, libere em Ajustes > Privacidade e Segurança > Rede Local.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 6)
                Text("Não achou? Digite o endereço da câmera:").font(.callout).foregroundStyle(.secondary)
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
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Câmeras de Casa")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !jaProcurou, !hospedandoTestesDeUnidade else { return }
            jaProcurou = true
            modelo.procurarCameras()
        }
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
