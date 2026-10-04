import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    try {
      stage.loadContent('pages/Index', (error) => {
        if (error.code) {
          console.error(`HarmonyScreen page could not load: ${error.code}`);
        }
      });
      stage.getMainWindow().then((win: window.Window) => {
        win.setWindowKeepScreenOn(true).catch(() => {
          console.warn('HarmonyScreen could not keep the screen awake');
        });
      }).catch(() => {
        console.warn('HarmonyScreen window is unavailable');
      });
    } catch {
      console.error('HarmonyScreen window initialization failed');
    }
  }
}
