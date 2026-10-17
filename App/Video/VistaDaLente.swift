import SwiftUI
import UIKit
import CamerasCore
import CamerasSessao

/// Uma lente na tela. Com o zoom ligado, entende pinça (amplia em volta dos dedos), arrastar
/// com zoom e toque duplo (amplia no ponto tocado ou volta ao normal); o toque simples vai para
/// `aoTocar` (na tela cheia, mostra os controles).
struct VistaDaLente: UIViewRepresentable {
    let distribuidor: DistribuidorDeQuadros
    let lente: LenteExibida
    @ObservedObject var zoom: EstadoDeZoom
    var zoomHabilitado = false
    var aoTocar: (() -> Void)? = nil

    func makeUIView(context: Context) -> LenteUIView {
        let v = LenteUIView(distribuidor: distribuidor, zoom: zoom)
        v.lente = lente
        v.zoomHabilitado = zoomHabilitado
        v.aoTocar = aoTocar
        return v
    }

    func updateUIView(_ v: LenteUIView, context: Context) {
        v.lente = lente
        v.zoomHabilitado = zoomHabilitado
        v.aoTocar = aoTocar
        v.aplicarZoom()
    }

    static func dismantleUIView(_ v: LenteUIView, coordinator: ()) {
        v.desconectar()
    }
}

final class LenteUIView: UIView, UIGestureRecognizerDelegate {
    private let exibidor = ExibidorDeVideo()
    private let camadaDeZoom = CALayer()
    private let distribuidor: DistribuidorDeQuadros
    private let zoom: EstadoDeZoom
    private var registro: UUID?
    private var escalaDaPinca: CGFloat = 1
    private var pinca: UIPinchGestureRecognizer!
    private var arrasto: UIPanGestureRecognizer!
    private var duplo: UITapGestureRecognizer!
    private var simples: UITapGestureRecognizer!

    var lente: LenteExibida = .movel { didSet { if lente != oldValue { setNeedsLayout() } } }
    var zoomHabilitado = false { didSet { atualizarGestos() } }
    var aoTocar: (() -> Void)? { didSet { atualizarGestos() } }

    init(distribuidor: DistribuidorDeQuadros, zoom: EstadoDeZoom) {
        self.distribuidor = distribuidor
        self.zoom = zoom
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        layer.addSublayer(camadaDeZoom)
        camadaDeZoom.addSublayer(exibidor.camada)
        let exibidor = self.exibidor
        registro = distribuidor.adicionar { exibidor.exibir($0) }

        pinca = UIPinchGestureRecognizer(target: self, action: #selector(pincou(_:)))
        arrasto = UIPanGestureRecognizer(target: self, action: #selector(arrastou(_:)))
        arrasto.maximumNumberOfTouches = 2
        duplo = UITapGestureRecognizer(target: self, action: #selector(tocouDuasVezes(_:)))
        duplo.numberOfTapsRequired = 2
        simples = UITapGestureRecognizer(target: self, action: #selector(tocou))
        simples.require(toFail: duplo)
        for g in [pinca, arrasto, duplo, simples] as [UIGestureRecognizer] {
            g.delegate = self
            addGestureRecognizer(g)
        }
        atualizarGestos()
        isAccessibilityElement = true
        accessibilityTraits = .image
    }

    /// Sem zoom nem toque, a vista não pega toque nenhum: o cartão da visão geral é um botão do
    /// SwiftUI e precisa receber o toque, e a rolagem da lista não pode ser presa pelo vídeo.
    private func atualizarGestos() {
        pinca?.isEnabled = zoomHabilitado
        arrasto?.isEnabled = zoomHabilitado
        duplo?.isEnabled = zoomHabilitado
        simples?.isEnabled = aoTocar != nil
        isUserInteractionEnabled = zoomHabilitado || aoTocar != nil
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith outro: UIGestureRecognizer) -> Bool {
        (g === pinca && outro === arrasto) || (g === arrasto && outro === pinca)
    }

    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        g === arrasto ? zoom.zoom > EstadoDeZoom.minimo : true          // sem zoom não há o que arrastar
    }

    required init?(coder: NSCoder) { fatalError("não usado") }

    func desconectar() {
        if let r = registro { distribuidor.remover(r) }
        registro = nil
        exibidor.limpar()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let w = bounds.width, h = bounds.height
        camadaDeZoom.setAffineTransform(.identity)
        camadaDeZoom.frame = bounds
        // O quadro traz as duas lentes empilhadas: a fixa em cima, a móvel embaixo. A camada tem
        // a altura do quadro inteiro e é deslocada para a metade certa ficar na janela.
        switch lente {
        case .movel: exibidor.camada.frame = CGRect(x: 0, y: -h, width: w, height: 2 * h)
        case .fixa: exibidor.camada.frame = CGRect(x: 0, y: 0, width: w, height: 2 * h)
        case .inteira: exibidor.camada.frame = CGRect(x: 0, y: 0, width: w, height: h)
        }
        aplicarZoom()
        CATransaction.commit()
    }

    func aplicarZoom() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if zoomHabilitado {
            let (x, y) = zoom.deslocamentoLimitado(largura: bounds.width, altura: bounds.height)
            camadaDeZoom.setAffineTransform(CGAffineTransform(translationX: x, y: y).scaledBy(x: zoom.zoom, y: zoom.zoom))
        } else {
            camadaDeZoom.setAffineTransform(.identity)
        }
        CATransaction.commit()
        accessibilityLabel = zoomHabilitado && zoom.zoom > 1.01 ? String(format: "Vídeo, zoom %.1f vezes", zoom.zoom) : "Vídeo"
    }

    // MARK: - Gestos

    @objc private func pincou(_ g: UIPinchGestureRecognizer) {
        guard zoomHabilitado else { return }
        switch g.state {
        case .began: escalaDaPinca = 1
        case .changed:
            let p = g.location(in: self)
            zoom.ampliar(por: Double(g.scale / escalaDaPinca), emX: p.x - bounds.midX, y: p.y - bounds.midY)
            escalaDaPinca = g.scale
            aplicarZoom()
        default: break
        }
    }

    @objc private func arrastou(_ g: UIPanGestureRecognizer) {
        guard zoomHabilitado, zoom.zoom > EstadoDeZoom.minimo else { return }
        let d = g.translation(in: self)
        g.setTranslation(.zero, in: self)
        // sem acumular além da borda: o que passa do limite se perde
        let (x, y) = zoom.deslocamentoLimitado(largura: bounds.width, altura: bounds.height)
        zoom.x = x + d.x
        zoom.y = y + d.y
        aplicarZoom()
    }

    @objc private func tocouDuasVezes(_ g: UITapGestureRecognizer) {
        guard zoomHabilitado else { return }
        if zoom.zoom > 1.01 {
            zoom.reiniciar()
        } else {
            let p = g.location(in: self)
            zoom.ampliar(por: 2.5, emX: p.x - bounds.midX, y: p.y - bounds.midY)
        }
        aplicarZoom()
    }

    @objc private func tocou() { aoTocar?() }
}
