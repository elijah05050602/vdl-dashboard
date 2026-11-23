const params = new URLSearchParams(window.location.search);
const countdown = document.getElementById('countdown');
let remaining = Number(params.get('retry')) || 15;

document.getElementById('url').textContent = params.get('url') || 'the server';
document.getElementById('error').textContent = `Details: ${params.get('error') || 'no answer'}`;
document.getElementById('retry').addEventListener('click', () => window.dashboardApp.retry());
document.getElementById('settings').addEventListener('click', () => window.dashboardApp.openSettings());

const timer = setInterval(() => {
  remaining -= 1;
  if (remaining <= 0) {
    clearInterval(timer);
    countdown.textContent = 'Trying again…';
    window.dashboardApp.retry();
    return;
  }
  countdown.textContent = `Trying again in ${remaining} seconds.`;
}, 1000);
