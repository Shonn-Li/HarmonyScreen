import receiver from 'libharmonyscreen.so';
import display from '@ohos.display';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct Index {
  private controller: XComponentController = new XComponentController();
  private timer: number = -1;
  private connectRequested: boolean = true;
  private foreground: boolean = true;
  private retryAt: number = 0;
  private appliedOrientation: number = -1;
  private orientationPending: boolean = false;

  private reportViewport(width: number, height: number): void {
    try {
      const screen = display.getDefaultDisplaySync();
      const w = Math.round(vp2px(width));
      const h = Math.round(vp2px(height));
      receiver.viewport(w, h, screen.xDPI, screen.yDPI);
      console.info(`HarmonyScreen viewport ${w}x${h}, DPI ${screen.xDPI}x${screen.yDPI}`);
    } catch { console.warn('HarmonyScreen could not read the panel size'); }
  }

  private updateOrientation(): void {
    const requested = receiver.orientation();
    if (requested < 0 || requested === this.appliedOrientation || this.orientationPending) { return; }
    this.orientationPending = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const mode = requested === 1 ? window.Orientation.PORTRAIT : requested === 2 ?
      window.Orientation.LANDSCAPE : window.Orientation.AUTO_ROTATION_RESTRICTED;
    window.getLastWindow(context).then((win: window.Window) => win.setPreferredOrientation(mode))
      .then(() => { this.appliedOrientation = requested; })
      .catch(() => { console.warn('HarmonyScreen orientation change was refused'); })
      .finally(() => { this.orientationPending = false; });
  }
  private hideControlsAt: number = 0;
  @State private message: string = 'Connect your Huawei by USB and start HarmonyScreen on the Mac.';
  @State private receivedFrames: number = 0;
  @State private active: boolean = false;
  @State private ready: boolean = false;
  @State private controlsVisible: boolean = true;
  @State private port: string = '54322';

  private connect(): void {
    if (!this.ready || !this.foreground || this.active) { return; }
    const portNumber = Number(this.port);
    if (portNumber < 1024 || portNumber > 65535 || !Number.isInteger(portNumber)) {
      this.message = 'Enter a port between 1024 and 65535';
      this.connectRequested = false;
      return;
    }
    this.retryAt = Date.now() + 3000;
    this.receivedFrames = 0;
    this.active = receiver.start(this.controller.getXComponentSurfaceId(), portNumber);
    this.message = this.active ? 'Connecting to your Mac…' : receiver.status();
    this.hideControlsAt = Date.now() + 2500;
  }

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (this.foreground) { this.updateOrientation(); }
      if (this.active) {
        this.message = receiver.status();
        const frames = receiver.frames();
        if (this.receivedFrames === 0 && frames > 0) {
          console.info('HarmonyScreen: first video frame displayed');
        }
        this.receivedFrames = frames;
        if (!receiver.running()) {
          this.active = false;
          this.controlsVisible = true;
          this.retryAt = Date.now() + 3000;
        } else if (frames > 0 && Date.now() >= this.hideControlsAt) {
          this.controlsVisible = false;
        }
      } else if (this.connectRequested && Date.now() >= this.retryAt) {
        this.connect();
      }
    }, 500);
  }

  onPageShow(): void { this.foreground = true; }
  onPageHide(): void {
    this.foreground = false;
    receiver.stop();
    this.active = false;
  }
  aboutToDisappear(): void {
    clearInterval(this.timer);
    receiver.stop();
  }
  onBackPress(): boolean {
    if (!this.controlsVisible) {
      this.controlsVisible = true;
      this.hideControlsAt = Date.now() + 5000;
      return true;
    }
    return false;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Keep one surface alive while controls appear/disappear above it.
      XComponent({ id: 'display', type: XComponentType.SURFACE, controller: this.controller })
        .width('100%').height('100%')
        .onAreaChange((_old: Area, area: Area) => { this.reportViewport(Number(area.width), Number(area.height)); })
        .onLoad(() => { this.ready = true; this.connect(); })
        .onDestroy(() => { receiver.stop(); this.ready = false; this.active = false; });

      Column() {}
        .width('100%').height('100%').backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.active && this.receivedFrames > 0) {
            this.controlsVisible = !this.controlsVisible;
            this.hideControlsAt = Date.now() + 5000;
          }
        });

      if (this.controlsVisible) {
        Column({ space: 12 }) {
          Row({ space: 16 }) {
            Column({ space: 4 }) {
              Text('HarmonyScreen').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#b9f3df');
              Text(this.message).fontSize(14).fontColor('#eeeeee');
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            if (this.receivedFrames > 0) {
              Text(`${this.receivedFrames} frames`).fontSize(12).fontColor('#cccccc');
              Button('Hide controls').onClick(() => { this.controlsVisible = false; });
            }
          }.padding(16).width('100%').backgroundColor('#D9111318').borderRadius(16);
          Blank();
          Row({ space: 12 }) {
            Text('Tap the screen to show or hide controls').fontSize(14).fontColor('#eeeeee')
              .layoutWeight(1);
            if (!this.active) {
              TextInput({ text: this.port, placeholder: 'Mac port' }).type(InputType.Number).width(110)
                .onChange((value: string) => { this.port = value; });
            }
            Button(this.active ? 'Disconnect' : 'Connect over USB').enabled(this.ready)
              .onClick(() => {
                if (this.active) {
                  this.connectRequested = false;
                  receiver.stop();
                  this.active = false;
                  this.receivedFrames = 0;
                  this.message = 'Disconnected';
                } else {
                  this.connectRequested = true;
                  this.connect();
                }
              });
          }.padding(16).width('100%').backgroundColor('#D9111318').borderRadius(16);
        }.padding(24).width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent);
      }
    }.width('100%').height('100%').backgroundColor('#000000')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}
