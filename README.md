# Câmeras de Casa (iPhone)

App nativo para iPhone que mostra e controla câmeras IP XiongMai (firmware "Sofia", as que
usam os apps XMEye e iCSee) direto pelo Wi-Fi de casa, sem depender da nuvem do fabricante.

É a versão para iPhone do app do Mac (o repositório `lan-cameras-mac`, do mesmo dono deste):
os dois usam o mesmo código para falar com as câmeras (`CamerasCore`) e para cuidar das
sessões abertas nelas (`CamerasSessao`); este repositório tem só as telas do iPhone.

## O que faz

- Acha as câmeras sozinho no Wi-Fi e pega delas mesmas o que precisa para entrar: ninguém
  digita usuário nem senha. Como o iOS só libera multicast com uma autorização especial da
  Apple, a busca bate na porta do ONVIF de cada endereço da rede, poucos de cada vez.
- Se o app do fabricante (iCSee, XMEye) trocar a senha de uma câmera, ou o roteador mudar o
  endereço dela, o app percebe quando ela recusa a senha guardada ou para de responder no
  endereço guardado (que pode ter ficado vazio ou com outro aparelho), procura a câmera pelo
  número de série, pega os dados novos com ela e reabre só as conexões dela. O vídeo não fica
  tentando de novo com a senha recusada: as câmeras podem bloquear a conta depois de várias
  tentativas erradas.
- Vídeo ao vivo (H.264 e H.265, decodificados por hardware), com as duas lentes das câmeras
  que têm duas: a móvel em destaque, a fixa num quadro menor no canto (opcional).
- Tela escura, como nos apps de câmeras de vigilância, com o mesmo desenho do app do Mac: na visão
  geral, uma câmera por linha ou numa grade de duas colunas, com o nome e o estado embaixo de cada
  vídeo e, em cima, quantas estão sem imagem; deitado, todas cabem na tela. Uma câmera sem imagem diz
  por quê e tem o botão "Tentar agora".
- Em retrato, o vídeo fica fixo no topo, com a fileira de ouvir, falar, foto e luz logo abaixo e os
  controles em cartões que rolam; deitado, o vídeo ocupa a tela inteira e os controles principais
  ficam por cima (um toque mostra ou esconde).
- Zoom digital por pinça e toque duplo; movimento (PTZ) segurando as setas do anel; posições salvas;
  luz branca e rastreio automático.
- Ouvir a câmera, falar por ela segurando o botão, sons prontos e texto falado.
- Foto da lente atual no app Fotos.
- Gravações: as câmeras gravam sozinhas no cartão de memória quando há movimento, com o som,
  mesmo com o celular desligado. O app mostra cada noite numa linha do tempo e numa grade com a
  foto do instante de cada movimento; o vídeo baixa do cartão e toca no próprio app, e dá para
  salvá-lo no Fotos ou compartilhá-lo.
- Em segundo plano o app solta as câmeras na hora (elas aguentam poucas conexões) e as reabre
  quando você volta.

## Compilar e testar

Requer um Mac com o Xcode 16 ou superior e o [XcodeGen](https://github.com/yonaskolb/XcodeGen).
O núcleo vem do repositório do Mac, que precisa ficar ao lado deste com o nome `lan-cameras-mac`;
se não estiver lá, o `compilar.sh` o clona sozinho do mesmo dono deste repositório:

```sh
brew install xcodegen
./scripts/compilar.sh          # gera o projeto, compila e testa no simulador (app e núcleo)
open CamerasDeCasa.xcodeproj   # se quiser abrir no Xcode
```

O projeto do Xcode não fica no repositório: ele é gerado a partir do `project.yml`.

A tela de gravações tem um teste de interface que usa as câmeras de mentira do repositório do Mac
(sem câmera de verdade nem a imagem de nenhuma casa); com elas atendendo, ele roda assim:

```sh
python3 ../lan-cameras-mac/scripts/camera-falsa.py --pasta /tmp/cameras-falsas &
TEST_RUNNER_CAMERAS_FALSAS=/tmp/cameras-falsas xcodebuild test -project CamerasDeCasa.xcodeproj \
  -scheme CamerasiOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:CamerasiOSUITests/GravacoesUITests
```

## Instalar no iPhone

É um app pessoal, instalado direto pelo Mac (sem App Store nem TestFlight). Com uma conta Apple
gratuita a assinatura vale 7 dias; depois disso o app não abre até ser instalado de novo.

1. No Xcode, entre com o seu Apple ID (Settings > Accounts).
2. Pareie o iPhone com o Mac uma vez pelo cabo ("Confiar neste computador") e ligue o Modo de
   Desenvolvedor no iPhone (Ajustes > Privacidade e Segurança).
3. Prepare a configuração local (time de assinatura e iPhone, guardados em
   `~/.config/lan-cameras/ios.env`, fora do repositório):

   ```sh
   ./scripts/preparar_ios_env.sh
   ```

4. Instale (e repita a cada 7 dias):

   ```sh
   ./scripts/instalar_iphone.sh
   ```

Na primeira instalação, confie no desenvolvedor no iPhone (Ajustes > Geral > Gerenciamento
de VPN e Dispositivo). Na primeira abertura o iPhone pergunta se o app pode procurar aparelhos
na rede local: é preciso permitir. A ajuda do app mostra até quando a assinatura vale.

Para acompanhar o que o app faz com as câmeras, no terminal do Mac e sem credenciais no texto:

```sh
./scripts/instalar_iphone.sh --depurar
```

## Privacidade

Usuário e senha das câmeras ficam só no iPhone, dentro do app e fora do backup do iCloud. O app
não abre nenhuma porta e só fala com as câmeras da rede local. Este repositório não contém
endereços, identificadores de aparelhos, dados de assinatura, credenciais nem imagens de
nenhuma instalação; para conferir antes de publicar qualquer mudança:

```sh
./scripts/verificar-privacidade.sh
```

## Licença

MIT: código aberto, use, modifique e distribua à vontade. Veja [LICENSE](LICENSE).
