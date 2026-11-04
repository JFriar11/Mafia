export function turnAlertKey(g){return g?.phase==='night'&&g.nightMine&&!g.ready.includes(g.me)?`${g.code}:${g.round}:${g.nightStep}:${g.me}`:null}
export function vibrateForTurn(device){try{return typeof device?.vibrate==='function'&&device.vibrate([220,120,220])===true}catch{return false}}
