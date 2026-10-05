export const start: (surfaceId: string, port: number) => boolean;
export const stop: () => void;
export const status: () => string;
export const frames: () => number;
export const running: () => boolean;
export const touch: (x: number, y: number, action: number) => void;
