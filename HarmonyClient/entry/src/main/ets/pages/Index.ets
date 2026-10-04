import receiver from 'libharmonyscreen.so';

@Entry
@Component
struct Index {
  private controller: XComponentController = new XComponentController();
  private timer: number = -1;
  @State private message: string = 'Connect your Huawei to the Mac with USB. Start HarmonyScreen on the Mac, then connect below.';
  @State private receivedFrames: number = 0;
  @State private active: boolean = false;
  @State private ready: boolean = false;
  @State private port: string = '54322';

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (this.active) {
        this.message = receiver.status();
        this.receivedFrames = receiver.frames();
      }
    }, 500);
  }
  aboutToDisappear(): void {
    clearInterval(this.timer);
    receiver.stop();
  }
  build() {
    Column({ space: 12 }) {
      Row() {
        Text('HarmonyScreen').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#b9f3df');
        Blank();
        Text(`${this.receivedFrames} frames displayed`).fontColor('#cccccc');
      }.width('100%');
      Text(this.message).fontSize(14).fontColor('#cccccc').width('100%');
      XComponent({ id: 'display', type: XComponentType.SURFACE, controller: this.controller })
        .width('100%').layoutWeight(1)
        .onLoad(() => { this.ready = true; })
        .onDestroy(() => { receiver.stop(); this.ready = false; this.active = false; });
      Row({ space: 12 }) {
        TextInput({ text: this.port, placeholder: 'Mac port' }).type(InputType.Number).width(120)
          .enabled(!this.active).onChange((value: string) => { this.port = value; });
        Button(this.active ? 'Disconnect' : 'Connect over USB')
          .enabled(this.ready)
          .onClick(() => {
            if (this.active) {
              receiver.stop(); this.active = false; this.message = 'Disconnected';
            } else {
              const portNumber = Number(this.port);
              if (portNumber < 1024 || portNumber > 65535 || !Number.isInteger(portNumber)) {
                this.message = 'Enter a port between 1024 and 65535'; return;
              }
              this.active = receiver.start(this.controller.getXComponentSurfaceId(), portNumber);
              this.message = this.active ? 'Connecting through HDC…' : receiver.status();
            }
          });
      }
    }.padding(18).width('100%').height('100%').backgroundColor('#111318');
  }
}
