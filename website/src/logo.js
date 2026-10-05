// The Lofer logo mark: the device's six-petal outline, drawn as a line (the
// latest brand mark). Same shape as the app icon and the 3D device (deviceShape.js).
import { deviceOutlineSvgPath } from './deviceShape.js';

export function logoMarkSvg(className, color = '#4a4741') {
  return `<svg class="${className}" viewBox="-56 -56 112 112" aria-hidden="true">
    <path d="${deviceOutlineSvgPath(100)}" fill="none" stroke="${color}" stroke-width="7" stroke-linejoin="round"/>
  </svg>`;
}
