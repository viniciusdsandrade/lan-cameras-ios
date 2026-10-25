import SwiftUI
import AVKit
import CamerasCore
import CamerasSessao

/// As cores das câmeras, na ordem delas: as mesmas na linha do tempo, nos cartões e no detalhe.
enum CoresDasCameras {
    private static let paleta: [Color] = [.orange, .cyan, .pink, .green, .purple, .yellow]

    static func cor(_ id: String, em cameras: [CameraConfig]) -> Color {
        paleta[(cameras.firstIndex { $0.id == id } ?? 0) % paleta.count]
    }
}

/// O que as câmeras gravaram sozinhas no cartão: as noites recentes, a linha do tempo da noite e a
/// grade com a foto do instante de cada movimento. Tocar abre o movimento em tela cheia.
struct TelaDeGravacoes: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var cartoes: CartoesDasCameras
    @State private var detalhe = false
    @State private var aberta = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dias
                LinhaDoTempo(cartoes: cartoes) { id in abrir(id) }
                    .padding(.horizontal, 16)
                conteudo
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            cartoes.recarregarEventos()
            cartoes.recarregarEstados()
        }
        .background(Tema.fundo.ignoresSafeArea())
        .navigationTitle("Gravações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Câmera", selection: $cartoes.camera) {
                        Label("Todas as câmeras", systemImage: "square.grid.2x2").tag(String?.none)
                        ForEach(modelo.cameras) { c in Text(c.nome).tag(Optional(c.id)) }
                    }
                    Picker("Período", selection: $cartoes.periodo) {
                        Label("Noite", systemImage: "moon").tag(CartoesDasCameras.Periodo.noite)
                        Label("Dia todo", systemImage: "sun.max").tag(CartoesDasCameras.Periodo.diaTodo)
                    }
                } label: {
                    Image(systemName: cartoes.camera == nil && cartoes.periodo == .noite
                          ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Câmera e período")
            }
        }
        .fullScreenCover(isPresented: $detalhe) { DetalheDoEvento(cartoes: cartoes).environmentObject(modelo) }
        .onAppear {
            // a tela de tela cheia, ao fechar, não deve buscar tudo de novo
            if !aberta {
                aberta = true
                cartoes.abrir()
            }
        }
    }

    private func abrir(_ id: String) {
        cartoes.selecionado = id
        detalhe = true
    }

    private var dias: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cartoes.diasRecentes, id: \.self) { d in
                    let escolhido = Calendar.current.isDate(d, inSameDayAs: cartoes.dia)
                    Button { cartoes.dia = d } label: {
                        Text(cartoes.rotulo(do: d))
                            .font(.subheadline.weight(escolhido ? .semibold : .regular))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 15)
                            .background(Capsule().fill(escolhido ? Color.accentColor : Tema.cartao))
                            .overlay(Capsule().strokeBorder(escolhido ? Color.clear : Tema.borda))
                            .foregroundStyle(escolhido ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(escolhido ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var conteudo: some View {
        switch cartoes.eventos {
        case .lendo:
            ProgressView("Procurando nas câmeras…")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        case .erro(let m):
            ContentUnavailableView {
                Label("As câmeras não responderam", systemImage: "wifi.exclamationmark")
            } description: {
                Text(m)
            } actions: {
                Button("Tentar de novo") { cartoes.recarregarEventos() }
            }
        case .pronto(let lista) where lista.isEmpty:
            ContentUnavailableView("Nada gravado", systemImage: "moon.zzz",
                                   description: Text("Nenhum movimento ficou gravado no cartão nesse período."))
        case .pronto(let lista):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(cartoes.falhas.sorted(by: { $0.key < $1.key }), id: \.key) { id, _ in
                    Label("\(modelo.camera(id: id)?.nome ?? "Uma câmera") não respondeu", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(lista) { e in
                        Button { abrir(e.id) } label: {
                            CartaoDoEvento(evento: e, imagem: cartoes.fotos[e.id],
                                           cor: CoresDasCameras.cor(e.idDaCamera, em: modelo.cameras),
                                           mostrarCamera: cartoes.camera == nil, baixando: cartoes.baixando[e.id])
                        }
                        .buttonStyle(.plain)
                        .task(id: e.id) { await cartoes.carregarFoto(e) }
                    }
                }
                rodape
            }
            .padding(.horizontal, 16)
        }
    }

    /// Como está o cartão de cada câmera: o espaço usado numa barra e o que ele grava.
    private var rodape: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cartões das câmeras", systemImage: "sdcard")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(modelo.cameras) { c in
                    if case .pronto(let e) = cartoes.estados[c.id] {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Circle().fill(CoresDasCameras.cor(c.id, em: modelo.cameras)).frame(width: 8, height: 8)
                                Text(c.nome).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(!e.temCartao ? "sem cartão" : (e.gravaPorMovimento == false ? "não grava" : "grava por movimento"))
                                    .font(.caption)
                                    .foregroundStyle(e.gravaPorMovimento == false || !e.temCartao ? Color.orange : Color.secondary)
                            }
                            if let livre = e.livreMB, let total = e.totalMB, total > 0 {
                                ProgressView(value: Double(max(0, total - livre)), total: Double(total))
                                    .tint(livre * 10 < total ? .orange : .accentColor)
                                Text("\(FormatoDasGravacoes.tamanho(mb: livre)) livres de \(FormatoDasGravacoes.tamanho(mb: total))"
                                     + (e.detectaPessoas == true ? " · só pessoas" : "") + (e.comSom == true ? " · com som" : ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Nota("As câmeras gravam sozinhas no cartão quando há movimento, mesmo com o celular desligado. O que cada uma grava se ajusta no app do fabricante (iCSee, XMEye).")
            }
            .cartao()
        }
        .padding(.top, 10)
    }
}

/// A noite inteira numa faixa: uma marca por movimento, na cor da câmera. Tocar abre o mais perto.
private struct LinhaDoTempo: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var cartoes: CartoesDasCameras
    let abrir: (String) -> Void

    var body: some View {
        let (de, ate) = cartoes.intervalo()
        let eventos: [EventoDoCartao] = { if case .pronto(let l) = cartoes.eventos { return l } else { return [] } }()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(resumo(eventos)).font(.subheadline.weight(.semibold))
                if case .lendo = cartoes.eventos { ProgressView().controlSize(.small) }
            }
            if cartoes.camera == nil { legenda(eventos) }
            GeometryReader { g in
                let w = g.size.width
                let total = max(1, ate.timeIntervalSince(de))
                let x = { (d: Date) in CGFloat(d.timeIntervalSince(de) / total) * w }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Tema.cartao).frame(width: w, height: 30)
                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Tema.borda).frame(width: w, height: 30)
                    ForEach(marcas(de: de, ate: ate), id: \.self) { h in
                        Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 30).offset(x: x(h))
                        Text("\(Calendar.current.component(.hour, from: h)) h")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .offset(x: x(h) + 3, y: 33)
                    }
                    ForEach(eventos) { e in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(CoresDasCameras.cor(e.idDaCamera, em: modelo.cameras))
                            .frame(width: max(4, CGFloat(e.gravacao.duracao / total) * w), height: 18)
                            .offset(x: x(e.inicio), y: 6)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { ponto in
                    let instante = de.addingTimeInterval(Double(ponto.x / max(1, w)) * total)
                    if let maisPerto = eventos.min(by: { abs($0.inicio.timeIntervalSince(instante)) < abs($1.inicio.timeIntervalSince(instante)) }) {
                        abrir(maisPerto.id)
                    }
                }
            }
            .frame(height: 48)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Linha do tempo: \(resumo(eventos))")
    }

    /// De que câmera é cada cor (só com todas as câmeras juntas).
    private func legenda(_ eventos: [EventoDoCartao]) -> some View {
        let comMovimento = Set(eventos.map(\.idDaCamera))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(modelo.cameras.filter { comMovimento.contains($0.id) }) { c in
                    HStack(spacing: 5) {
                        Circle().fill(CoresDasCameras.cor(c.id, em: modelo.cameras)).frame(width: 8, height: 8)
                        Text(c.nome).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }

    /// Uma marca a cada 3 h na noite (a cada 6 h no dia inteiro), nas horas cheias: a tela é estreita.
    private func marcas(de: Date, ate: Date) -> [Date] {
        let cal = Calendar.current
        let passo = cartoes.periodo == .noite ? 3 : 6
        var h = cal.date(bySetting: .minute, value: 0, of: de) ?? de
        if h < de { h = cal.date(byAdding: .hour, value: 1, to: h)! }
        var lista: [Date] = []
        while h < ate {
            if cal.component(.hour, from: h) % passo == 0 { lista.append(h) }
            h = cal.date(byAdding: .hour, value: 1, to: h)!
        }
        return lista
    }

    private func resumo(_ eventos: [EventoDoCartao]) -> String {
        switch cartoes.eventos {
        case .lendo: return "Procurando nas câmeras…"
        case .erro: return "As câmeras não responderam"
        case .pronto:
            guard !eventos.isEmpty else { return "Nenhum movimento gravado" }
            let cameras = Set(eventos.map(\.idDaCamera)).count
            return "\(eventos.count) \(eventos.count == 1 ? "movimento" : "movimentos")"
                + (cartoes.camera == nil ? " em \(cameras) \(cameras == 1 ? "câmera" : "câmeras")" : "")
        }
    }
}

/// Um movimento na grade: a foto do instante (as duas lentes, se a câmera tiver duas), a hora, a
/// duração e, com todas as câmeras juntas, de qual câmera é.
private struct CartaoDoEvento: View {
    let evento: EventoDoCartao
    let imagem: CGImage?
    let cor: Color
    let mostrarCamera: Bool
    let baixando: Double?

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Color.black
            .aspectRatio(evento.duasLentes ? 640.0 / 720.0 : 16.0 / 9.0, contentMode: .fit)
            .overlay {
                if let imagem {
                    Image(decorative: imagem, scale: 1).resizable().scaledToFill()
                } else {
                    Image(systemName: evento.foto == nil ? "film" : "photo")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.15))
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom).frame(height: 56)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(FormatoDasGravacoes.hora(evento.inicio))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                    if mostrarCamera {
                        HStack(spacing: 4) {
                            Circle().fill(cor).frame(width: 6, height: 6)
                            Text(evento.nomeDaCamera).lineLimit(1)
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .foregroundStyle(.white)
                .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                Group {
                    if let baixando {
                        ProgressView(value: baixando).progressViewStyle(.circular).tint(.white)
                            .padding(5).background(Tema.sobreVideo, in: Circle())
                    } else {
                        Text(FormatoDasGravacoes.duracaoCurta(evento.gravacao.duracao))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Tema.sobreVideo, in: Capsule())
                    }
                }
                .padding(6)
            }
            .clipShape(forma)
            .overlay(forma.strokeBorder(Tema.borda))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(evento.nomeDaCamera), \(FormatoDasGravacoes.hora(evento.inicio)), \(GravacaoPorMovimento.duracao(evento.gravacao.duracao))")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Detalhe

/// Um movimento em tela cheia: a foto do instante e, ao tocar ▶, o vídeo baixado do cartão. Deslizar
/// para o lado passa de um movimento para outro; compartilhar inclui salvar o vídeo no Fotos.
private struct DetalheDoEvento: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var cartoes: CartoesDasCameras
    @Environment(\.dismiss) private var fechar
    @State private var player: AVPlayer?
    @State private var tocando: String?

    var body: some View {
        NavigationStack {
            Group {
                if let e = cartoes.eventoSelecionado {
                    conteudo(e)
                } else {
                    ContentUnavailableView("Nenhum movimento escolhido", systemImage: "film")
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { fechar() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Fechar")
                }
                if let e = cartoes.eventoSelecionado {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text(e.nomeDaCamera).font(.headline)
                            Text(e.inicio.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) + ", " + FormatoDasGravacoes.hora(e.inicio))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if let url = cartoes.videoPronto(e) {
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                                .accessibilityLabel("Compartilhar ou salvar o vídeo")
                        }
                    }
                }
            }
        }
        .onChange(of: cartoes.selecionado) { _, _ in
            player?.pause()
            player = nil
            tocando = nil
        }
        .onDisappear { player?.pause() }
    }

    private func conteudo(_ e: EventoDoCartao) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            ZStack {
                Color.black
                if tocando == e.id, let player {
                    VideoPlayer(player: player)
                } else {
                    if let imagem = cartoes.fotos[e.id] {
                        Image(decorative: imagem, scale: 1).resizable().scaledToFit()
                    }
                    if let p = cartoes.baixando[e.id] {
                        Color.black.opacity(0.55)
                        VStack(spacing: 10) {
                            ProgressView(value: p).progressViewStyle(.circular).controlSize(.large).tint(.white)
                            Text("Baixando do cartão… \(Int(p * 100))%").font(.callout).foregroundStyle(.white)
                        }
                    } else {
                        Button { tocar(e) } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 76, height: 76)
                                .background(.black.opacity(0.55), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
                        }
                        .accessibilityLabel("Assistir")
                    }
                }
            }
            .aspectRatio(e.duasLentes ? 640.0 / 720.0 : 16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Tema.raio, style: .continuous))
            .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                if v.translation.width < -60 { cartoes.selecionarMaisAntigo() } else if v.translation.width > 60 { cartoes.selecionarMaisNovo() }
            })
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(CoresDasCameras.cor(e.idDaCamera, em: modelo.cameras)).frame(width: 8, height: 8)
                    Text([e.inicio.formatted(.relative(presentation: .named)),
                          GravacaoPorMovimento.duracao(e.gravacao.duracao),
                          ByteCountFormatter.string(fromByteCount: Int64(e.gravacao.bytes), countStyle: .file)].joined(separator: " · "))
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                if case .pronto(let estado) = cartoes.estados[e.idDaCamera] {
                    Label(FormatoDasGravacoes.cartao(estado), systemImage: "sdcard")
                        .font(.caption)
                        .foregroundStyle(estado.gravaPorMovimento == false ? .orange : .secondary)
                }
            }
            HStack {
                Button { cartoes.selecionarMaisAntigo() } label: { Label("Anterior", systemImage: "chevron.left") }
                    .labelStyle(.iconOnly)
                Spacer()
                Button {
                    fechar()
                    modelo.selecionar(.camera(e.idDaCamera))
                } label: {
                    Label("Ver ao vivo", systemImage: "dot.radiowaves.left.and.right").font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Abre \(e.nomeDaCamera) ao vivo")
                Spacer()
                Button { cartoes.selecionarMaisNovo() } label: { Label("Seguinte", systemImage: "chevron.right") }
                    .labelStyle(.iconOnly)
            }
            .font(.title2)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 12)
        .task(id: e.id) { await cartoes.carregarFoto(e) }
    }

    private func tocar(_ e: EventoDoCartao) {
        Task {
            guard let url = await cartoes.assistir(e), cartoes.selecionado == e.id else { return }
            let p = AVPlayer(url: url)
            player = p
            tocando = e.id
            p.play()
        }
    }
}

// MARK: - Textos

enum FormatoDasGravacoes {
    static func hora(_ d: Date) -> String {
        d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }

    /// "0:21", "3:05".
    static func duracaoCurta(_ s: Double) -> String {
        let t = Int(s.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    /// "13,3 GB livres de 116 GB · grava por movimento · só pessoas · com som".
    static func cartao(_ e: EstadoDoCartao) -> String {
        guard e.temCartao else { return "sem cartão de memória" }
        var partes: [String] = []
        if let livre = e.livreMB, let total = e.totalMB {
            partes.append("\(tamanho(mb: livre)) livres de \(tamanho(mb: total))")
        }
        partes.append(e.gravaPorMovimento == false ? "não grava por movimento" : "grava por movimento")
        if e.detectaPessoas == true { partes.append("só pessoas") }
        if e.comSom == true { partes.append("com som") }
        return partes.joined(separator: " · ")
    }

    /// A câmera conta em MB de 1024 KB.
    static func tamanho(mb: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(mb) * 1_048_576, countStyle: .memory)
    }
}
