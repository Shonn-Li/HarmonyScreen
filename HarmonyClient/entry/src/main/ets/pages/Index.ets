import receiver from 'libharmonyscreen.so';
import display from '@ohos.display';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct Index {
  private controller: XComponentController = new XComponentController();
  private timer: number = -1;
  @State private connectRequested: boolean = true;
  @StorageLink('harmonyForeground') @Watch('foregroundChanged') private foreground: boolean = true;
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
      window.Orientation.LANDSCAPE : window.Orientation.AUTO_ROTATION;
    window.getLastWindow(context).then((win: window.Window) => win.setPreferredOrientation(mode))
      .then(() => { this.appliedOrientation = requested; })
      .catch(() => { console.warn('HarmonyScreen orientation change was refused'); })
      .finally(() => { this.orientationPending = false; });
  }
  private hideControlsAt: number = 0;
  private statsLogAt: number = 0;
  @State private message: string = 'Waiting for Mac';
  @State private nextStep: string = 'Connect this Huawei to your Mac with a data cable. Unlock it and approve USB debugging, then open HarmonyScreen on the Mac.';
  @State private receivedFrames: number = 0;
  @State private displayFPS: number = 0;
  @State private showFPS: boolean = false;
  @State private active: boolean = false;
  @State private ready: boolean = false;
  @State private controlsVisible: boolean = true;
  @State private port: string = '54322';
  @State private placement: number = -1;

  private foregroundChanged(): void {
    if (this.foreground) { this.retryAt = 0; return; }
    receiver.stop();
    this.active = false;
    this.receivedFrames = 0;
    this.displayFPS = 0;
    this.controlsVisible = true;
  }

  private placeScreen(side: number): void {
    const alignment = this.placement >= 0 ? this.placement % 3 : 1;
    if (!receiver.place(side, alignment)) {
      this.nextStep = 'Reconnect after updating HarmonyScreen on your Mac to change screen position.';
    }
    this.hideControlsAt = Date.now() + 10000;
  }

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
    this.displayFPS = 0;
    this.active = receiver.start(this.controller.getXComponentSurfaceId(), portNumber);
    // The connection worker may retry; the controls and instructions stay still.
    this.message = 'Waiting for Mac';
    this.hideControlsAt = Date.now() + 2500;
  }

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (this.foreground) { this.updateOrientation(); }
      if (this.active) {
        const frames = receiver.frames();
        if (this.receivedFrames === 0 && frames > 0) {
          console.info('HarmonyScreen: first video frame displayed');
        }
        this.receivedFrames = frames;
        this.displayFPS = receiver.fps();
        this.placement = receiver.placement();
        if (frames > 0) { this.message = 'Connected over USB'; }
        if (frames > 0 && Date.now() >= this.statsLogAt) {
          console.info(`HarmonyScreen receiver: ${this.displayFPS.toFixed(1)} FPS; ${frames} frames rendered`);
          this.statsLogAt = Date.now() + 5000;
        }
        if (!receiver.running()) {
          const reason = receiver.status();
          console.info(`HarmonyScreen reconnect: ${reason}`);
          this.active = false;
          this.receivedFrames = 0;
          this.displayFPS = 0;
          this.controlsVisible = true;
          this.message = 'Waiting for Mac';
          this.nextStep = reason.includes('picture') || reason.includes('decoder') || reason.includes('Decoder') ?
            'On your Mac, open HarmonyScreen and check Screen Recording permission. If the picture is still missing, try a lower resolution.' :
            'Connect this Huawei to your Mac with a data cable. Unlock it and approve USB debugging, then open HarmonyScreen on the Mac.';
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
    this.foregroundChanged();
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

  private openYouWo(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ action: 'ohos.want.action.viewData', uri: 'https://youwo.ai' })
      .catch(() => { this.message = 'Visit YouWo.ai in your browser'; });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Keep one surface alive while controls appear/disappear above it.
      XComponent({ id: 'display', type: XComponentType.SURFACE, controller: this.controller })
        .width('100%').height('100%')
        .onAreaChange((_old: Area, area: Area) => { this.reportViewport(Number(area.width), Number(area.height)); })
        .onLoad(() => { this.ready = true; this.connect(); })
        .onDestroy(() => { receiver.stop(); this.ready = false; this.active = false; });

      // Do not leave a frozen desktop visible after the connection has ended.
      if (!this.active || this.receivedFrames === 0) {
        Column() {}.width('100%').height('100%').backgroundColor('#000000')
          .hitTestBehavior(HitTestMode.None);
      }

      Column() {}
        .width('100%').height('100%').backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.active && this.receivedFrames > 0) {
            this.controlsVisible = !this.controlsVisible;
            this.hideControlsAt = Date.now() + 5000;
          }
        });

      if (this.showFPS && !this.controlsVisible && this.active) {
        Column() {
          Row() {
            Blank();
            Text(`${this.displayFPS.toFixed(1)} FPS`).fontSize(14).fontColor('#b9f3df')
              .padding(10).backgroundColor('#C0111318').borderRadius(10);
          }
          Blank();
        }.padding(16).width('100%').height('100%').hitTestBehavior(HitTestMode.None);
      }

      if (this.controlsVisible) {
        Column({ space: 12 }) {
          Row({ space: 16 }) {
            Column({ space: 4 }) {
              Text('HarmonyScreen').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#b9f3df');
              Text('by YouWo.ai · Free').fontSize(12).fontColor('#b9f3df')
                .onClick(() => { this.openYouWo(); });
              Text(this.message).fontSize(14).fontColor('#eeeeee');
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            if (this.receivedFrames > 0) {
              Text(`${this.displayFPS.toFixed(1)} FPS`).fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor('#b9f3df');
              Button('Hide controls').onClick(() => { this.controlsVisible = false; });
            }
          }.padding(16).width('100%').backgroundColor('#D9111318').borderRadius(16);
          Blank();
          if (this.receivedFrames === 0) {
            Column({ space: 8 }) {
              Text(this.nextStep).fontSize(17).fontColor('#eeeeee');
              Text(this.connectRequested ? 'We’ll reconnect automatically when it is ready.' : 'Automatic reconnect is paused.')
                .fontSize(13).fontColor('#b9f3df');
            }.padding(20).width('100%').backgroundColor('#D9111318').borderRadius(16);
          }
          if (this.receivedFrames > 0 && this.placement >= 0) {
            Column({ space: 8 }) {
              Text('Place this screen beside your Mac').fontSize(14).fontColor('#eeeeee');
              Row({ space: 8 }) {
                ForEach(['Left', 'Right', 'Above', 'Below'], (label: string, index: number) => {
                  Button(label)
                    .backgroundColor(Math.floor(this.placement / 3) === index ? '#b9f3df' : '#30353e')
                    .fontColor(Math.floor(this.placement / 3) === index ? '#111318' : '#eeeeee')
                    .layoutWeight(1).onClick(() => { this.placeScreen(index); });
                });
              }.width('100%');
            }.padding(12).width('100%').backgroundColor('#D9111318').borderRadius(12);
          }
          if (this.receivedFrames > 0) {
            Row({ space: 12 }) {
              Text('Stream FPS · fewer updates when the desktop is still').fontSize(12)
                .fontColor('#eeeeee').layoutWeight(1);
              Button(this.showFPS ? 'FPS always on' : 'Keep FPS visible')
                .onClick(() => { this.showFPS = !this.showFPS; this.hideControlsAt = Date.now() + 5000; });
            }.padding(12).width('100%').backgroundColor('#D9111318').borderRadius(12);
          }
          Row({ space: 12 }) {
            Text(this.receivedFrames > 0 ? 'Tap the screen to show or hide controls' : 'USB reconnect is automatic')
              .fontSize(14).fontColor('#eeeeee')
              .layoutWeight(1);
            if (!this.connectRequested) {
              TextInput({ text: this.port, placeholder: 'Mac port' }).type(InputType.Number).width(110)
                .onChange((value: string) => { this.port = value; });
            }
            if (this.connectRequested && this.receivedFrames === 0) {
              Button('Retry now').enabled(this.ready).onClick(() => {
                receiver.stop(); this.active = false; this.retryAt = 0; this.connect();
              });
            }
            Button(this.connectRequested ? (this.receivedFrames > 0 ? 'Disconnect' : 'Pause reconnect') : 'Connect over USB').enabled(this.ready)
              .onClick(() => {
                if (this.connectRequested) {
                  this.connectRequested = false;
                  receiver.stop();
                  this.active = false;
                  this.receivedFrames = 0;
                  this.displayFPS = 0;
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
