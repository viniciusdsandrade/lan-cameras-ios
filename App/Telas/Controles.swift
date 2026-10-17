import SwiftUI
import CamerasCore
import CamerasSessao

/// Os controles de uma câmera em retrato, abaixo do vídeo: movimento, imagem, posições salvas,
/// luz e rastreio, som e foto.
struct Controles: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var sessao: SessaoDaCamera
    @ObservedObject private var zoom: EstadoDeZoom
    @State private var nomeDaPosicao = ""
    @State private var salvandoPosicao = false
    @State private var texto = ""
    @State private var apagando: PresetDaCamera?
    @FocusState private var digitando: Bool

    init(sessao: SessaoDaCamera) {
        self.sessao = sessao
        self.zoom = sessao.zoom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            movimento
            imagem
            som
            posicoes
            luzERastreio
        }
        .alert("Salvar a posição atual", isPresented: $salvandoPosicao) {
            TextField("Nome (ex.: Vista da rua)", text: $nomeDaPosicao)
            Button("Salvar") { sessao.salvarPosicao(nome: nomeDaPosicao) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A câmera guarda para onde ela está apontando agora.")
        }
        .confirmationDialog("Apagar esta posição?", isPresented: Binding(get: { apagando != nil }, set: { if !$0 { apagando = nil } }),
                            titleVisibility: .visible, presenting: apagando) { p in
            Button("Apagar \"\(p.nome)\"", role: .destructive) { sessao.apagar(p) }
            Button("Cancelar", role: .cancel) {}
        }
        .onChange(of: modelo.volume) { _, novo in sessao.volumeMudou(novo) }
    }

    // MARK: - Movimento

    private var movimento: some View {
        Secao(titulo: "Mover", simbolo: "arrow.up.and.down.and.arrow.left.and.right") {
            HStack {
                Spacer()
                ControleDeMovimento(sessao: sessao)
                Spacer()
            }
            Picker("Velocidade", selection: $modelo.velocidade) {
                Text("Lenta").tag(0.2)
                Text("Média").tag(0.4)
                Text("Rápida").tag(0.7)
            }
            .pickerStyle(.segmented)
            Text("Segure uma seta: a câmera se mexe enquanto você segura e para ao soltar.")
                .font(.caption).foregroundStyle(.secondary)
            if sessao.estado?.rastreioLigado == true, let s = sessao.estado?.rastreioVoltaEmSegundos {
                Label("Rastreio ligado: ela volta sozinha ao ponto de vigia depois de \(s) s.", systemImage: "scope")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Imagem

    private var imagem: some View {
        Secao(titulo: "Imagem", simbolo: "photo") {
            Picker("Qualidade", selection: $modelo.qualidadeHD) {
                Text("HD").tag(true)
                Text("Leve").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: modelo.qualidadeHD) { _, _ in modelo.recomecarSessaoDaCamera() }
            HStack(spacing: 12) {
                Button { zoom.definir(zoom.zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 30, height: 30) }
                    .accessibilityLabel("Diminuir o zoom")
                Slider(value: Binding(get: { zoom.zoom }, set: { zoom.definir($0) }), in: EstadoDeZoom.minimo...EstadoDeZoom.maximo)
                    .accessibilityLabel("Zoom")
                Button { zoom.definir(zoom.zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 30, height: 30) }
                    .accessibilityLabel("Aumentar o zoom")
                Button(String(format: "%.1f×", zoom.zoom)) { zoom.reiniciar() }
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 44)
                    .accessibilityLabel("Voltar o zoom ao normal")
            }
            .buttonStyle(.bordered)
            Text("O zoom é digital (as câmeras não têm zoom óptico). Pinça ou toque duplo no vídeo também ampliam.")
                .font(.caption).foregroundStyle(.secondary)
            if sessao.camera.duasLentes {
                Toggle("Mostrar a lente fixa", isOn: $modelo.mostrarLenteFixa)
            }
            Button { sessao.tirarFoto() } label: {
                Label("Tirar foto", systemImage: "camera.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Som

    private var som: some View {
        Secao(titulo: "Som", simbolo: "speaker.wave.2") {
            HStack(spacing: 10) {
                Button { sessao.alternarOuvir() } label: {
                    Label(sessao.ouvindo ? "Ouvindo" : "Ouvir", systemImage: sessao.ouvindo ? "speaker.wave.2.fill" : "speaker.slash")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(sessao.ouvindo ? .accentColor : .secondary)
                .accessibilityValue(sessao.ouvindo ? "ligado" : "desligado")
                BotaoDeFalar(sessao: sessao)
            }
            if sessao.falandoAoVivo {
                ProgressView(value: Double(sessao.nivelDoMicrofone)).tint(.red)
                Text("Enquanto você fala, o som da câmera fica mudo para não dar eco.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $modelo.volume, in: 5...100, step: 5).accessibilityLabel("Volume na câmera")
                Text("\(Int(modelo.volume))%").font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
            }
            Text("O alto-falante da câmera é alto: 10% já se ouve bem.").font(.caption).foregroundStyle(.secondary)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { botaoDeSom(.campainha); botaoDeSom(.bip) }
                GridRow { botaoDeSom(.alarme); botaoDeSom(.sirene) }
            }
            Button(role: .destructive) { sessao.pararSom() } label: {
                Label("Parar o som", systemImage: "stop.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            HStack {
                TextField("O que a câmera deve falar", text: $texto)
                    .textFieldStyle(.roundedBorder)
                    .focused($digitando)
                    .submitLabel(.send)
                    .onSubmit(falar)
                Button("Falar", action: falar)
                    .buttonStyle(.bordered)
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty || sessao.ocupadas.contains("texto"))
            }
        }
    }

    private func botaoDeSom(_ som: Som) -> some View {
        Button { sessao.tocar(som) } label: { Text(som.rotulo).frame(maxWidth: .infinity, minHeight: 36) }
            .buttonStyle(.bordered)
            .disabled(sessao.ocupadas.contains("som"))
            .accessibilityHint("Toca \(som.rotulo.lowercased()) no alto-falante da câmera")
    }

    private func falar() {
        digitando = false
        sessao.falarTexto(texto)
    }

    // MARK: - Posições salvas

    private var posicoes: some View {
        Secao(titulo: "Posições salvas", simbolo: "mappin.and.ellipse") {
            let lista = sessao.estado?.presets ?? []
            if lista.isEmpty {
                Text(sessao.estado == nil ? "lendo…" : "Nenhuma posição salva.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(lista, id: \.token) { p in
                HStack {
                    Text(p.nome).lineLimit(1)
                    Spacer()
                    if sessao.presetsDoApp.contains(p.token) {
                        Button { apagando = p } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .tint(.red)
                            .accessibilityLabel("Apagar a posição \(p.nome)")
                            .disabled(sessao.ocupadas.contains("apagar-\(p.token)"))
                    } else {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tertiary)
                            .accessibilityLabel("já vinha na câmera; o app não apaga")
                    }
                    Button("Ir") { sessao.irPara(p) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Ir para a posição \(p.nome)")
                        .disabled(sessao.ocupadas.contains("preset-\(p.token)"))
                }
            }
            Button {
                nomeDaPosicao = ""
                salvandoPosicao = true
            } label: { Label("Salvar a posição atual", systemImage: "plus") }
                .disabled(sessao.ocupadas.contains("salvar-preset"))
            Text("Só as posições criadas por este app podem ser apagadas aqui.").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Luz e rastreio

    private var luzERastreio: some View {
        Secao(titulo: "Luz e rastreio", simbolo: "lightbulb") {
            Picker("Luz", selection: Binding(
                get: { sessao.luzPedida ?? sessao.estado?.luz },
                set: { if let m = $0 { sessao.definirLuz(m) } }
            )) {
                Text("Automática").tag(ModoDaLuz?.some(.automatico))
                Text("Ligada").tag(ModoDaLuz?.some(.ligada))
                Text("Desligada").tag(ModoDaLuz?.some(.desligada))
            }
            .pickerStyle(.segmented)
            .disabled(sessao.estado?.luz == nil || sessao.ocupadas.contains("luz"))
            Toggle(isOn: Binding(
                get: { sessao.rastreioPedido ?? sessao.estado?.rastreioLigado ?? false },
                set: { sessao.definirRastreio($0) }
            )) { Text("Rastreio automático") }
                .disabled(sessao.estado?.rastreioLigado == nil || sessao.ocupadas.contains("rastreio"))
            Text("Com o rastreio ligado a câmera segue o que se mexe e depois volta sozinha ao ponto de vigia: o movimento manual \"se desfaz\".")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(sessao.estado?.avisos ?? [], id: \.self) { a in
                Label(a, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

/// "Segure para falar": o microfone do iPhone vai para o alto-falante da câmera enquanto o
/// dedo estiver no botão.
struct BotaoDeFalar: View {
    @ObservedObject var sessao: SessaoDaCamera
    var compacto = false

    var body: some View {
        BotaoDePressao(descricao: "Segure para falar pela câmera", ativo: sessao.falandoAoVivo, corAtiva: .red,
                       aoPressionar: { sessao.iniciarFalaAoVivo() }, aoSoltar: { sessao.pararFalaAoVivo() }) { aceso in
            Label(aceso ? (sessao.falandoAoVivo ? "Falando…" : "Abrindo…") : (compacto ? "Falar" : "Segure para falar"),
                  systemImage: aceso ? "mic.fill" : "mic")
                .font(.body.weight(.medium))
                .foregroundStyle(aceso ? .white : .red)
                .frame(maxWidth: compacto ? nil : .infinity, minHeight: 44)
                .padding(.horizontal, compacto ? 14 : 0)
                .background(RoundedRectangle(cornerRadius: 10).fill(aceso ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.red.opacity(0.15))))
        }
    }
}
