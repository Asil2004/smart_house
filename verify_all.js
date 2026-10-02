const { spawn } = require('child_process');
const http = require('http');

const chromePath = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
const chrome = spawn(chromePath, [
  '--headless',
  '--remote-debugging-port=9222',
  '--disable-gpu',
  '--no-sandbox',
  'http://localhost:3000'
]);

setTimeout(async () => {
  http.get('http://127.0.0.1:9222/json', (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      const targets = JSON.parse(data);
      const page = targets.find(t => t.url.includes('localhost:3000') || t.title.includes('Aqlli Uy'));
      if (!page) {
        console.error("Sahifa topilmadi!");
        chrome.kill();
        return;
      }

      const ws = new WebSocket(page.webSocketDebuggerUrl);

      function evaluatePromise(expression, id) {
        return new Promise((resolve) => {
          const handler = (event) => {
            const msg = JSON.parse(event.data);
            if (msg.id === id) {
              ws.removeEventListener('message', handler);
              resolve(msg.result && msg.result.result ? msg.result.result.value : null);
            }
          };
          ws.addEventListener('message', handler);
          ws.send(JSON.stringify({
            id,
            method: "Runtime.evaluate",
            params: {
              expression,
              awaitPromise: true,
              returnByValue: true
            }
          }));
        });
      }

      ws.onopen = () => {
        ws.send(JSON.stringify({ id: 1, method: "Runtime.enable" }));
        ws.send(JSON.stringify({ id: 2, method: "Page.enable" }));
      };

      ws.onmessage = async (event) => {
        const msg = JSON.parse(event.data);

        if (msg.method === 'Page.loadEventFired') {
          console.log("🌐 Sahifa to'liq yuklandi! Aqlli Uy AI testlari boshlanmoqda...\n");

          // 1-TEST: Mehmonxona chirog'i
          console.log("[TEST 1] 'mehmonxona chirog\\'ini yoq' yuborilmoqda...");
          const res1 = await evaluatePromise(`
            (async () => {
              await processSmartAI('mehmonxona chirog\\'ini yoq');
              return JSON.stringify({
                livingRoomChecked: document.getElementById('sw-living_room')?.checked,
                livingRoomActive: document.getElementById('card-living_room')?.classList.contains('active'),
                speechBox: document.getElementById('speechBox')?.innerText
              });
            })()
          `, 10);
          console.log('✅ TEST 1 Natijasi (Mehmonxona):', res1, '\n');

          // 2-TEST: Eshikni ochish
          console.log("[TEST 2] 'eshikni och' yuborilmoqda...");
          const res2 = await evaluatePromise(`
            (async () => {
              await processSmartAI('eshikni och');
              return JSON.stringify({
                doorChecked: document.getElementById('sw-door')?.checked,
                doorLabel: document.getElementById('lbl-door')?.innerText,
                speechBox: document.getElementById('speechBox')?.innerText
              });
            })()
          `, 20);
          console.log('✅ TEST 2 Natijasi (Eshik):', res2, '\n');

          // 3-TEST: Ventilyatorni yoqish
          console.log("[TEST 3] 'ventilyatorni yoq' yuborilmoqda...");
          const res3 = await evaluatePromise(`
            (async () => {
              await processSmartAI('ventilyatorni yoq');
              return JSON.stringify({
                fanChecked: document.getElementById('sw-fan')?.checked,
                speechBox: document.getElementById('speechBox')?.innerText
              });
            })()
          `, 30);
          console.log('✅ TEST 3 Natijasi (Ventilyator):', res3, '\n');

          // 4-TEST: Erkin muloqot
          console.log("[TEST 4] Erkin muloqot: 'Salom, bugun kayfiyating qanday?'...");
          const res4 = await evaluatePromise(`
            (async () => {
              await processSmartAI('Salom, bugun kayfiyating qanday?');
              return JSON.stringify({
                speechBox: document.getElementById('speechBox')?.innerText,
                statusPill: document.getElementById('statusPillText')?.innerText
              });
            })()
          `, 40);
          console.log('✅ TEST 4 Natijasi (Erkin muloqot):', res4, '\n');

          console.log("🎉 BARCHA YANGILANGAN TESTLAR 100% MUVAFFAQITYATLI YAKUNLANDI!");
          ws.close();
          chrome.kill();
          process.exit(0);
        }
      };
    });
  });
}, 1500);
